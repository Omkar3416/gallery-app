import 'package:flutter/material.dart';
import 'package:gallery_app/features/backup/data/cloud_sync_repository_impl.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:gallery_app/core/widgets/app_nav.dart';
import 'package:gallery_app/services/isar/isar_service.dart';
import 'package:gallery_app/features/gallery/data/mappers/media_mapper.dart';
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';

import '../../../../core/config/app_settings.dart';
import '../../../../services/aws/auth/aws_auth.dart';
import '../../../../services/aws/storage/aws_storage.dart';

/// Simple state machine for a row.
enum UploadState { idle, running, paused, done, error }

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final CloudSyncRepositoryImpl _repo;

  // Per-item runtime
  final Map<String, UploadState> _state = {}; // id -> state
  final Map<String, http.Client> _clients = {}; // id -> http client (to cancel)
  final Map<String, String?> _errors = {}; // id -> last error text

  // Bulk
  bool _bulkInProgress = false;
  bool _cancelAll = false;

  @override
  void initState() {
    super.initState();
    _repo = CloudSyncRepositoryImpl(
      auth: AwsAuth(),
      storage: AwsStorage(),
      isar: IsarService(),
    );
  }

  String _keyFor(MediaItem it) =>
      it.id?.toString() ?? it.assetId ?? it.uri ?? 'unknown';

  String _safeName(MediaItem it) {
    final u = it.uri ?? '';
    if (u.isNotEmpty && u.contains('/')) return u.split('/').last;
    if (it.assetId != null) return it.assetId!;
    return 'Item';
  }

  // --- guardrails + snackbars ------------------------------------------------

  bool get _cloudReady {
    final s = AppSettings();
    if (!s.awsEnabled) {
      _snack(
        'Cloud is OFF. Turn it ON in Settings → Developer.',
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.push('/settings'),
        ),
      );
      return false;
    }
    if (s.lambdaUrl.trim().isEmpty) {
      _snack(
        'Lambda URL missing. Add it in Settings → Developer.',
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.push('/settings'),
        ),
      );
      return false;
    }
    if (s.appKey.isEmpty) {
      _snack(
        'Tip: set x-app-key in Settings → Developer (if your Lambda checks it).',
        duration: const Duration(seconds: 3),
      );
    }
    return true;
  }

  void _snack(
    String msg, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), action: action, duration: duration),
    );
  }

  // --- per-item actions -------------------------------------------------------

  Future<void> _startOne(MediaItem it) async {
    if (!_cloudReady) return;

    final id = _keyFor(it);
    if (_state[id] == UploadState.running) return;

    setState(() {
      _state[id] = UploadState.running;
      _errors[id] = null;
    });

    final client = http.Client();
    _clients[id] = client;

    try {
      final ok = await _repo.backupWithClient(it, client: client);
      if (!mounted) return;

      // NOTE: after success, Isar marks item as backedUp=true.
      // The StreamBuilder removes it from the "pending" list automatically.
      setState(() {
        _state[id] = ok ? UploadState.done : UploadState.error;
        _clients.remove(id)?.close();
        if (!ok) _errors[id] = 'Could not back up (no file?)';
      });
      _snack(
        ok ? 'Backed up "${_safeName(it)}"' : 'Failed: "${_safeName(it)}"',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state[id] = UploadState.error;
        _clients.remove(id)?.close();
        _errors[id] = e.toString();
      });
      _snack('Backup failed: $e');
    }
  }

  void _pauseOne(MediaItem it) {
    final id = _keyFor(it);
    if (_state[id] == UploadState.running) {
      _clients.remove(id)?.close(); // cancels the HTTP request
      setState(() => _state[id] = UploadState.paused);
      _snack('Paused "${_safeName(it)}".');
    }
  }

  void _resumeOne(MediaItem it) {
    final id = _keyFor(it);
    if (_state[id] == UploadState.paused || _state[id] == UploadState.error) {
      _startOne(it);
    }
  }

  void _stopOne(MediaItem it) {
    final id = _keyFor(it);
    // "Stop" = cancel current request and go back to idle (cloud icon)
    _clients.remove(id)?.close();
    setState(() => _state[id] = UploadState.idle);
  }

  // --- bulk actions -----------------------------------------------------------

  Future<void> _backupAll(List<MediaItem> items) async {
    if (!_cloudReady || _bulkInProgress) return;

    setState(() {
      _bulkInProgress = true;
      _cancelAll = false;
    });

    for (final it in items) {
      if (_cancelAll) break;

      final id = _keyFor(it);
      if (_state[id] == UploadState.running) continue; // skip current
      await _startOne(it);
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() => _bulkInProgress = false);
    if (_cancelAll) _snack('Bulk backup stopped.');
  }

  void _pauseAllActive() {
    for (final c in _clients.values) {
      c.close();
    }
    setState(() {
      for (final id in _clients.keys.toList()) {
        _state[id] = UploadState.paused;
      }
      _clients.clear();
      _cancelAll = true;
      _bulkInProgress = false;
    });
    _snack('Paused all active uploads.');
  }

  void _stopAll() {
    for (final c in _clients.values) {
      c.close();
    }
    setState(() {
      for (final id in _state.keys.toList()) {
        if (_state[id] == UploadState.running ||
            _state[id] == UploadState.paused) {
          _state[id] = UploadState.idle;
        }
      }
      _clients.clear();
      _cancelAll = true;
      _bulkInProgress = false;
    });
    _snack('Stopped all queued uploads.');
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = AppSettings();
    final inDev = s.devMode;
    final awsOn = s.awsEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!inDev)
            const _BannerInfo(
              color: Colors.redAccent,
              text: 'Production mode: Cloud features are hidden/disabled.',
            )
          else if (!awsOn)
            const _BannerInfo(
              color: Colors.amber,
              text:
                  'Cloud is OFF. Turn it ON in Settings (Developer mode) to enable backups.',
            ),

          if (inDev && awsOn)
            _HeaderControls(
              bulkInProgress: _bulkInProgress,
              onBackupAll: () async {
                final entries = await IsarService().getAll();
                final items = entries
                    .where((e) => !e.backedUp)
                    .map(MediaMapper.toEntity)
                    .toList();
                await _backupAll(items);
              },
              onPauseAll: _pauseAllActive,
              onStopAll: _stopAll,
            ),

          Expanded(
            child: (!inDev || !awsOn)
                ? const _Disabled()
                : StreamBuilder(
                    stream: IsarService().watchUnbacked(),
                    builder: (context, snap) {
                      final entries = (snap.data ?? []);
                      final items = entries.map(MediaMapper.toEntity).toList();
                      if (items.isEmpty) return const _Empty();

                      return LayoutBuilder(
                        builder: (context, box) {
                          final wide = box.maxWidth >= 720;
                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final it = items[i];
                              final id = _keyFor(it);
                              final st = _state[id] ?? UploadState.idle;
                              final err = _errors[id];

                              return _ItemCard(
                                item: it,
                                state: st,
                                error: err,
                                dense: !wide,
                                onStart: () => _startOne(it),
                                onPause: () => _pauseOne(it),
                                onResume: () => _resumeOne(it),
                                onStop: () => _stopOne(it),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavBar(current: AppTab.backup),
    );
  }
}

// ===== Header row (Back up all / Pause all / Stop all) =======================

class _HeaderControls extends StatelessWidget {
  final bool bulkInProgress;
  final VoidCallback onBackupAll;
  final VoidCallback onPauseAll;
  final VoidCallback onStopAll;
  const _HeaderControls({
    required this.bulkInProgress,
    required this.onBackupAll,
    required this.onPauseAll,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: Text(bulkInProgress ? 'Backing up…' : 'Back up all'),
            onPressed: bulkInProgress ? null : onBackupAll,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.pause_circle_filled),
            label: const Text('Pause all'),
            onPressed: onPauseAll,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop all'),
            onPressed: onStopAll,
          ),
        ],
      ),
    );
  }
}

// ===== Per-item card =========================================================

class _ItemCard extends StatelessWidget {
  final MediaItem item;
  final UploadState state;
  final String? error;
  final bool dense;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _ItemCard({
    required this.item,
    required this.state,
    required this.error,
    required this.dense,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final icon = item.type == 'video'
        ? Icons.videocam_outlined
        : Icons.image_outlined;

    final title = Text(
      item.uri?.split('/').last ?? item.assetId ?? 'Item',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final subtitle = Text(
      [
        'type: ${item.type}',
        if (item.tags.isNotEmpty) 'tags: ${item.tags.join(", ")}',
        if (error != null) 'error: $error',
      ].join(' • '),
    );

    final actionRow = switch (state) {
      UploadState.running => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          IconButton(
            tooltip: 'Pause',
            onPressed: onPause,
            icon: const Icon(Icons.pause),
          ),
          IconButton(
            tooltip: 'Stop',
            onPressed: onStop,
            icon: const Icon(Icons.stop),
          ),
        ],
      ),
      UploadState.paused => Wrap(
        spacing: 6,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
            onPressed: onResume,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            onPressed: onStop,
          ),
        ],
      ),
      UploadState.done => Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 6),
          Text('Backed up'),
        ],
      ),
      UploadState.error => Wrap(
        spacing: 6,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: onStart,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Dismiss'),
            onPressed: onStop,
          ),
        ],
      ),
      _ => IconButton(
        tooltip: 'Back up this item',
        icon: const Icon(Icons.cloud_upload_outlined),
        onPressed: onStart,
      ),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(radius: dense ? 18 : 22, child: Icon(icon)),
          title: title,
          subtitle: subtitle,
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: actionRow,
          ),
        ),
      ),
    );
  }
}

// ===== helpers ==============================================================

class _BannerInfo extends StatelessWidget {
  final String text;
  final Color color;
  const _BannerInfo({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.15),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            color == Colors.amber
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Disabled extends StatelessWidget {
  const _Disabled();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Backup is unavailable in Production mode or when Cloud is OFF.',
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('All items are already marked as backed up.'),
      ),
    );
  }
}
