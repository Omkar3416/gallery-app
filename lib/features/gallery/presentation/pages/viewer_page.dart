// lib/features/gallery/presentation/pages/viewer_page.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:gallery_app/core/config/app_settings.dart';
import 'package:gallery_app/features/backup/data/cloud_sync_repository_impl.dart';
import 'package:gallery_app/features/backup/domain/usecases/backup_item.dart';
import 'package:gallery_app/features/gallery/data/mappers/media_mapper.dart';
import 'package:gallery_app/services/aws/auth/aws_auth.dart';
import 'package:gallery_app/services/aws/storage/aws_storage.dart';
import 'package:gallery_app/services/isar/isar_service.dart';
import 'package:gallery_app/services/isar/schemas/media_entry.dart';
import 'package:gallery_app/services/media_indexer/media_delete.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../gallery/domain/entities/media_item.dart';
import '../../../gallery/data/datasources/local_gallery_source.dart';
import '../../../gallery/data/repositories/gallery_repository_impl.dart';
import '../../../gallery/domain/usecases/add_media_from_paths.dart';
import '../../../../features/ai/on_device_tagger.dart';
import 'viewer_args.dart';

class ViewerPage extends StatefulWidget {
  final ViewerArgs args;
  const ViewerPage({super.key, required this.args});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final PageController _pc;
  late int _index;

  late final BackupItem _backupOne;
  bool _backupBusy = false;

  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.args.index.clamp(0, widget.args.items.length - 1);
    _pc = PageController(initialPage: _index);

    final repo = CloudSyncRepositoryImpl(
      auth: AwsAuth(),
      storage: AwsStorage(),
      isar: IsarService(),
    );
    _backupOne = BackupItem(repo);
  }

  MediaItem get _current => widget.args.items[_index];

  bool get _currentBackedUp =>
      (_current.cloudKey ?? '').isNotEmpty || (_current.backedUp == true);

  // ---------- helpers ----------

  Future<File?> _resolveFile(MediaItem item) async {
    if (item.assetId != null) {
      final ent = await AssetEntity.fromId(item.assetId!);
      final f = await ent?.file;
      if (f != null && await f.exists()) return f;
    }
    final u = item.uri;
    if (u != null && u.isNotEmpty) {
      final f = File(u);
      if (await f.exists()) return f;
    }
    return null;
  }

  void _removeCurrentFromList({bool animate = false}) {
    if (widget.args.items.isEmpty) return;

    final hadLast = widget.args.items.length == 1;
    if (hadLast) {
      // nothing left; exit viewer
      if (mounted) context.pop();
      return;
    }

    setState(() {
      widget.args.items.removeAt(_index);
      if (_index >= widget.args.items.length) {
        _index = widget.args.items.length - 1;
      }
    });

    // realign page controller to the new index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animate) {
        _pc.animateToPage(
          _index,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      } else {
        _pc.jumpToPage(_index);
      }
    });
  }

  // ---------- actions on current item ----------

  Future<void> _shareCurrent() async {
    final f = await _resolveFile(_current);
    if (f == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accessible file to share')),
      );
      return;
    }
    final mime = _current.type == 'video' ? 'video/*' : 'image/*';
    await Share.shareXFiles([XFile(f.path, mimeType: mime)]);
  }

  Future<void> _backupCurrent() async {
    final s = AppSettings();

    if (!s.awsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cloud is OFF. Turn it ON in Settings → Developer.'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
      return;
    }
    if (s.lambdaUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lambda URL is not set. Add it in Settings → Developer.'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
      return;
    }
    if (s.appKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tip: If your Lambda checks x-app-key, set it in Settings → Developer.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => _backupBusy = true);
    try {
      final ok = await _backupOne(_current);
      if (!mounted) return;

      if (ok && _current.id != null) {
        final entry = await IsarService().db.mediaEntrys.get(_current.id!);
        if (entry != null) {
          final refreshed = MediaMapper.toEntity(entry);
          setState(() => widget.args.items[_index] = refreshed);
        }
      }

      setState(() => _backupBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Backed up this item.' : 'Could not back up this item.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _backupBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  Future<void> _openFromCloud() async {
    final key = _current.cloudKey ?? '';
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not in cloud yet')),
      );
      return;
    }
    context.push('/cloudPreview', extra: key);
  }

  Future<void> _toggleFavorite() async {
    if (_current.id == null) return;
    final newVal = !_current.favorite;
    await IsarService().toggleFavorite(_current.id!, newVal);
    final entry = await IsarService().db.mediaEntrys.get(_current.id!);
    if (entry != null) {
      setState(() => widget.args.items[_index] = MediaMapper.toEntity(entry));
    }
  }

  Future<void> _deleteCurrent() async {
    if (_current.id == null) return;

    final entry = await IsarService().db.mediaEntrys.get(_current.id!);
    final isTrashed = (entry?.trashed ?? false);

    if (!isTrashed) {
      await IsarService().moveToTrash(_current.id!);
      if (!mounted) return;
      // remove immediately from viewer list and show snack with UNDO
      _removeCurrentFromList();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moved to Trash'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              if (_current.id != null) {
                await IsarService().restoreFromTrash(_current.id!);
              }
            },
          ),
        ),
      );
      return;
    }

    // In Trash: Restore or Delete permanently
    final pick = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('This item is in Trash'),
        content: const Text('Do you want to permanently delete it, or restore it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, 'restore'), child: const Text('Restore')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(c, 'delete'),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (!mounted || pick == null || pick == 'cancel') return;

    if (pick == 'restore') {
      await IsarService().restoreFromTrash(_current.id!);
      // If viewer started from Trash list, remove it immediately
      _removeCurrentFromList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored')),
      );
      return;
    }

    // delete permanently
    if (entry != null) {
      if (entry.assetId != null && entry.assetId!.isNotEmpty) {
        await MediaDelete.permanentDelete(assetId: entry.assetId);
      } else if (entry.uri.isNotEmpty) {
        await MediaDelete.permanentDelete(uri: entry.uri);
      } else {
        await IsarService().deletePermanently(id: entry.id);
      }
    }
    if (!mounted) return;
    _removeCurrentFromList();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted permanently')),
    );
  }

  Future<void> _renameCurrent() async {
    final path = _current.uri;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rename not available for system-managed items')),
      );
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File missing on disk')),
      );
      return;
    }
    final dir = p.dirname(path);
    final oldName = p.basename(path);
    final ext = p.extension(path);
    final base = oldName.substring(0, oldName.length - ext.length);

    final ctl = TextEditingController(text: base);
    final newBase = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctl,
          decoration: InputDecoration(hintText: base, suffixText: ext),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newBase == null || newBase.isEmpty) return;

    final newPath = p.join(dir, '$newBase$ext');
    try {
      await file.rename(newPath);
      if (_current.id != null) {
        await IsarService().updatePath(id: _current.id!, newPath: newPath);
        final entry = await IsarService().db.mediaEntrys.get(_current.id!);
        if (entry != null) {
          setState(() => widget.args.items[_index] = MediaMapper.toEntity(entry));
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renamed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: $e')),
      );
    }
  }

  Future<void> _copyCurrent() async {
    final path = _current.uri;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copy not available for system-managed items')),
      );
      return;
    }
    final src = File(path);
    if (!await src.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File missing on disk')),
      );
      return;
    }
    final dir = p.dirname(path);
    final name = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    String dest = p.join(dir, '$name (copy)$ext');
    int counter = 1;
    while (await File(dest).exists()) {
      dest = p.join(dir, '$name (copy $counter)$ext');
      counter++;
    }
    try {
      await src.copy(dest);
      final repo = GalleryRepositoryImpl(
        local: LocalGallerySource(IsarService()),
        tagger: OnDeviceTagger(),
      );
      final add = AddMediaFromPaths(repo);
      await add([dest], _current.type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copy failed: $e')),
      );
    }
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    final total = widget.args.items.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // content
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleChrome,
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: total,
              itemBuilder: (context, i) {
                final item = widget.args.items[i];
                final heroTag = 'm-${item.id ?? item.assetId ?? item.uri ?? i}';
                return _ViewerItem(
                  item: item,
                  key: ValueKey(item.id ?? item.assetId ?? item.uri ?? i),
                  heroTag: heroTag,
                  showBackedBadge:
                      (item.cloudKey ?? '').isNotEmpty || (item.backedUp == true),
                );
              },
            ),
          ),

          // top glass bar (back + cloud)
          _GlassTopBar(
            visible: _chromeVisible,
            title: '${_index + 1} / $total',
            backedUp: _currentBackedUp,
            busy: _backupBusy,
            onBack: () => context.pop(),
            onBackup: _backupCurrent,
            onOpenCloud: _openFromCloud,
          ),

          // bottom glass bar — Share | Favourite | Edit | Delete | More
          _GlassActionBar(
            visible: _chromeVisible,
            isFav: _current.favorite,
            canEdit: _current.type == 'image' || _current.type == 'video',
            onShare: _shareCurrent,
            onFavToggle: _toggleFavorite,
            onEdit: () {
              final m = _current;
              if (m.type == 'video') {
                context.push('/edit-video', extra: m);
              } else {
                context.push('/edit-image', extra: m);
              }
            },
            onDelete: _deleteCurrent,
            onMore: (choice) {
              switch (choice) {
                case 'rename':
                  _renameCurrent();
                  break;
                case 'copy':
                  _copyCurrent();
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------- glass chrome ----------

class _GlassTopBar extends StatelessWidget {
  final bool visible;
  final String title;
  final bool backedUp;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onBackup;
  final VoidCallback onOpenCloud;

  const _GlassTopBar({
    required this.visible,
    required this.title,
    required this.backedUp,
    required this.busy,
    required this.onBack,
    required this.onBackup,
    required this.onOpenCloud,
  });

  @override
  Widget build(BuildContext context) {
    final bar = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            if (backedUp)
              IconButton(
                tooltip: 'Open from cloud',
                onPressed: onOpenCloud,
                icon: const Icon(Icons.cloud_done, color: Colors.white),
              )
            else if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              IconButton(
                tooltip: 'Back up to cloud',
                onPressed: onBackup,
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
              ),
          ],
        ),
      ),
    );

    return _glassBar(visible: visible, alignTop: true, child: bar);
  }
}

class _GlassActionBar extends StatelessWidget {
  final bool visible;
  final bool isFav;
  final bool canEdit;
  final VoidCallback onShare;
  final VoidCallback onFavToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String choice) onMore;

  const _GlassActionBar({
    required this.visible,
    required this.isFav,
    required this.canEdit,
    required this.onShare,
    required this.onFavToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final bar = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Action(icon: Icons.share, label: 'Share', onTap: onShare),
              _Action(
                icon: isFav ? Icons.favorite : Icons.favorite_border,
                label: 'Favourite',
                onTap: onFavToggle,
              ),
              _Action(
                icon: Icons.edit,
                label: 'Edit',
                onTap: canEdit ? onEdit : null,
              ),
              _Action(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: onDelete,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: onMore,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'copy', child: Text('Copy')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return _glassBar(visible: visible, alignTop: false, child: bar);
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

Widget _glassBar({required bool visible, required bool alignTop, required Widget child}) {
  final container = ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  return Positioned(
    left: 0, right: 0, top: alignTop ? 0 : null, bottom: alignTop ? null : 0,
    child: AnimatedSlide(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      offset: visible ? Offset.zero : Offset(0, alignTop ? -0.2 : 0.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: visible ? 1 : 0,
        child: container,
      ),
    ),
  );
}

// ------------------ media renderer ------------------

class _ViewerItem extends StatefulWidget {
  final MediaItem item;
  final String heroTag;
  final bool showBackedBadge;
  const _ViewerItem({
    super.key,
    required this.item,
    required this.heroTag,
    required this.showBackedBadge,
  });

  @override
  State<_ViewerItem> createState() => _ViewerItemState();
}

class _ViewerItemState extends State<_ViewerItem> {
  VideoPlayerController? _vp;
  ChewieController? _chewie;
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'video') _initVideo();
  }

  Future<void> _initVideo() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      File? file;
      if (widget.item.assetId != null) {
        final ent = await AssetEntity.fromId(widget.item.assetId!);
        final f = await ent?.file;
        if (f != null && await f.exists()) file = f;
      }
      if (file == null && (widget.item.uri?.isNotEmpty ?? false)) {
        final f = File(widget.item.uri!);
        if (await f.exists()) file = f;
      }
      if (file == null) throw 'Could not open video file';

      _vp = VideoPlayerController.file(file);
      await _vp!.initialize();
      _chewie = ChewieController(
        videoPlayerController: _vp!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowPlaybackSpeedChanging: true,
        allowMuting: true,
      );
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroTag =
        'm-${widget.item.id ?? widget.item.assetId ?? widget.item.uri ?? 'x'}';

    if (widget.item.type != 'video') {
      return Stack(
        children: [
          _buildImage(heroTag),
          if (widget.showBackedBadge)
            const Positioned(top: 12, right: 12, child: _BackedChip()),
        ],
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_err!, style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    final ar = _vp?.value.aspectRatio ?? (16 / 9);
    return Stack(
      children: [
        Center(
          child: Hero(
            tag: heroTag,
            child: AspectRatio(
              aspectRatio: ar == 0 ? 16 / 9 : ar,
              child: _chewie == null ? const SizedBox.shrink() : Chewie(controller: _chewie!),
            ),
          ),
        ),
        if (widget.showBackedBadge)
          const Positioned(top: 12, right: 12, child: _BackedChip()),
      ],
    );
  }

  Widget _buildImage(String heroTag) {
    return FutureBuilder<Widget>(
      future: () async {
        File? f;
        if (widget.item.assetId != null) {
          final ent = await AssetEntity.fromId(widget.item.assetId!);
          f = await ent?.file;
        } else if (widget.item.uri != null && widget.item.uri!.isNotEmpty) {
          final ff = File(widget.item.uri!);
          if (await ff.exists()) f = ff;
        }
        if (f == null) {
          return const Center(
            child: Text('Image not available', style: TextStyle(color: Colors.white70)),
          );
        }
        return Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(child: Image.file(f, fit: BoxFit.contain)),
          ),
        );
      }(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return snap.data!;
      },
    );
  }
}

class _BackedChip extends StatelessWidget {
  const _BackedChip();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.55),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white24),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('Backed up', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
