import 'dart:io';
import 'dart:ui' as ui; // glass AppBar blur
import 'package:flutter/material.dart';
import 'package:gallery_app/core/widgets/app_nav.dart';
import 'package:gallery_app/features/gallery/presentation/pages/viewer_args.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_settings.dart';
import '../../../../core/utils/date_groups.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/backup/data/cloud_sync_repository_impl.dart';
import '../../../../services/aws/auth/aws_auth.dart';
import '../../../../services/aws/storage/aws_storage.dart';
import '../../../../services/isar/isar_service.dart';
import '../../../../services/isar/schemas/media_entry.dart';
import '../../../../services/media_indexer/media_delete.dart';
import '../../../gallery/data/mappers/media_mapper.dart';
import '../../domain/entities/media_item.dart';
import '../widgets/system_thumb.dart';
import '../widgets/video_thumb.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

// Dual view modes
enum _ViewMode { grid, list }

class _AlbumsPageState extends State<AlbumsPage>
    with SingleTickerProviderStateMixin {
  final tabs = const [
    _TabSpec('All', _AlbumType.all),
    _TabSpec('Photos', _AlbumType.photos),
    _TabSpec('Videos', _AlbumType.videos),
    _TabSpec('Favourites', _AlbumType.fav),
    _TabSpec('WhatsApp', _AlbumType.whatsapp),
    _TabSpec('Telegram', _AlbumType.telegram),
    _TabSpec('Downloads', _AlbumType.downloads),
    _TabSpec('Screenshots', _AlbumType.screenshots),
    _TabSpec('Recent', _AlbumType.recent),
    _TabSpec('Trash', _AlbumType.trash),
  ];

  late final TabController _tc;
  final List<GlobalKey<_AlbumViewState>> _keys = [];

  _ViewMode _mode = _ViewMode.grid;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: tabs.length, vsync: this)
      ..addListener(() => setState(() {}));
    _keys.addAll(List.generate(tabs.length, (_) => GlobalKey<_AlbumViewState>()));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  bool get _isTrashTab => tabs[_tc.index].type == _AlbumType.trash;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // glass
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 8,
        toolbarHeight: 64,
        title: const Text('Albums'),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(.65),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96), // extra height for Delete All row
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tc,
                isScrollable: true,
                tabs: [for (final t in tabs) Tab(text: t.title)],
              ),
              // Under the TabBar: show Delete All (Trash tab only)
              // if (_isTrashTab)
              //   SafeArea(
              //     top: false,
              //     bottom: false,
              //     child: Align(
              //       alignment: Alignment.centerRight,
              //       child: Padding(
              //         padding: const EdgeInsets.only(right: 8, top: 6),
              //         child: IconButton.filledTonal(
              //           tooltip: 'Delete all (permanent)',
              //           style: ButtonStyle(
              //             backgroundColor: WidgetStatePropertyAll(
              //               Colors.red.withOpacity(.15),
              //             ),
              //             foregroundColor: const WidgetStatePropertyAll(Colors.red),
              //           ),
              //           onPressed: () => _keys[_tc.index]
              //               .currentState
              //               ?.deleteAllTrashedFromAppBar(),
              //           icon: const Icon(Icons.delete_forever_rounded),
              //         ),
              //       ),
              //     ),
              //   ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        actions: [
          // grid/list toggle
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ToggleButtons(
              isSelected: [
                _mode == _ViewMode.grid,
                _mode == _ViewMode.list,
              ],
              onPressed: (i) => setState(() {
                _mode = i == 0 ? _ViewMode.grid : _ViewMode.list;
              }),
              borderRadius: BorderRadius.circular(10),
              constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.grid_view_rounded),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.view_list_rounded),
                ),
              ],
            ),
          ),
          // TRASH tab: 3-dot menu in APP BAR (Cancel selection · Select all · Delete all)
          if (_isTrashTab)
            PopupMenuButton<String>(
              tooltip: 'Trash options',
              onSelected: (v) {
                final st = _keys[_tc.index].currentState;
                if (st == null) return;
                switch (v) {
                  case 'cancel':
                    st.clearSelectionFromAppBar();
                    break;
                  case 'select_all':
                    st.selectAllVisibleFromAppBar();
                    break;
                  case 'delete_all':
                    st.deleteAllTrashedFromAppBar();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cancel', child: Text('Cancel selection')),
                PopupMenuItem(value: 'select_all', child: Text('Select all')),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Text('Delete all (permanent)'),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          // ⚠️ Settings button removed per request
                        // Under the TabBar: show Delete All (Trash tab only)
              if (_isTrashTab)
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 6),
                      child: IconButton.filledTonal(
                        tooltip: 'Delete all (permanent)',
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            Colors.red.withOpacity(.15),
                          ),
                          foregroundColor: const WidgetStatePropertyAll(Colors.red),
                        ),
                        onPressed: () => _keys[_tc.index]
                            .currentState
                            ?.deleteAllTrashedFromAppBar(),
                        icon: const Icon(Icons.delete_forever_rounded),
                      ),
                    ),
                  ),
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 150),
        child: TabBarView(
          controller: _tc,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _AlbumView(
                key: _keys[i],
                type: tabs[i].type,
                mode: _mode,
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppNavBar(current: AppTab.albums),
    );
  }
}

enum _AlbumType {
  all,
  photos,
  videos,
  fav,
  whatsapp,
  telegram,
  downloads,
  screenshots,
  recent,
  trash,
}

class _TabSpec {
  final String title;
  final _AlbumType type;
  const _TabSpec(this.title, this.type);
}

class _AlbumView extends StatefulWidget {
  final _AlbumType type;
  final _ViewMode mode;
  const _AlbumView({super.key, required this.type, required this.mode});

  @override
  State<_AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends State<_AlbumView> {
  final _selected = <int>{};
  bool get inSelection => _selected.isNotEmpty;
  final List<int> _visibleIds = [];

  // Called from parent AppBar menu (Trash tab)
  void clearSelectionFromAppBar() => _clearSelection();
  void selectAllVisibleFromAppBar() => _selectAllVisible();
  Future<void> deleteAllTrashedFromAppBar() => _deleteAllTrashed();

  String _keyFor(MediaItem m) =>
      m.id?.toString() ?? m.assetId ?? m.uri ?? 'noid-${m.hashCode}';

  Future<void> _shareSelected() async {
    if (_selected.isEmpty) return;
    final isar = IsarService().db;
    final paths = <String>[];
    for (final id in _selected) {
      final e = await isar.mediaEntrys.get(id);
      if (e == null) continue;
      if (e.uri.isNotEmpty && File(e.uri).existsSync()) {
        paths.add(e.uri);
        continue;
      }
      if (e.assetId != null) {
        final ent = await AssetEntity.fromId(e.assetId!);
        final f = await ent?.file;
        if (f != null && await f.exists()) paths.add(f.path);
      }
    }
    if (paths.isEmpty) return;
    await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
  }

  void _selectAllVisible() => setState(() => _selected.addAll(_visibleIds));
  void _clearSelection() => setState(_selected.clear);

  Future<void> _deleteAllTrashed() async {
    if (widget.type != _AlbumType.trash) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all in Trash?'),
        content: const Text(
          'This will permanently delete all items in Trash. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final isar = IsarService().db;
    final all = await isar.mediaEntrys.where().findAll();
    final trashed = all.where((e) => e.trashed).toList();

    for (final e in trashed) {
      if (e.assetId != null && e.assetId!.isNotEmpty) {
        await MediaDelete.permanentDelete(assetId: e.assetId);
      } else if (e.uri.isNotEmpty) {
        await MediaDelete.permanentDelete(uri: e.uri);
      } else {
        await IsarService().deletePermanently(id: e.id);
      }
    }
    if (!mounted) return;
    _selected.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${trashed.length} item(s)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = IsarService();
    final s = AppSettings();
    final cloudOn = s.awsEnabled;

    Stream<List<MediaItem>> stream;
    switch (widget.type) {
      case _AlbumType.photos:
        stream = isar.watchPhotos().map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.videos:
        stream = isar.watchVideos().map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.fav:
        stream = isar.watchFavorites().map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.whatsapp:
        stream = isar
            .watchBucketContains('whatsapp')
            .map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.telegram:
        stream = isar
            .watchBucketContains('telegram')
            .map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.downloads:
        stream = isar
            .watchBucketContains('download')
            .map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.screenshots:
        stream = isar
            .watchAllNotTrashed()
            .map((l) => l.map(MediaMapper.toEntity).toList())
            .map((list) {
          const k = 'screenshot';
          return list.where((m) {
            final inBucket = m.bucket.toLowerCase().contains(k);
            final hasTag = m.tags.any((t) => t.toLowerCase() == k);
            return inBucket || hasTag;
          }).toList();
        });
        break;
      case _AlbumType.recent:
        stream = isar
            .watchRecentDays(14)
            .map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.trash:
        stream =
            isar.watchTrashed().map((l) => l.map(MediaMapper.toEntity).toList());
        break;
      case _AlbumType.all:
      default:
        stream = isar
            .watchAllNotTrashed()
            .map((l) => l.map(MediaMapper.toEntity).toList());
        break;
    }

    return StreamBuilder<List<MediaItem>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('No items'));
        }

        final sections = groupByFriendlyDate(items);

        _visibleIds
          ..clear()
          ..addAll(
            sections
                .expand((s) => s.items)
                .where((m) => m.id != null)
                .map((m) => m.id!),
          );

        final List<MediaItem> allFlat = [for (final s in sections) ...s.items];
        final Map<String, int> indexByKey = {
          for (int i = 0; i < allFlat.length; i++) _keyFor(allFlat[i]): i,
        };

        return LayoutBuilder(
          builder: (context, c) {
            int cols = Responsive.columnsForWidth(c.maxWidth).clamp(2, 6);

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    for (final section in sections) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                          child: Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      if (widget.mode == _ViewMode.grid)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = section.items[index];
                                final selected =
                                    item.id != null && _selected.contains(item.id);

                                final key = ValueKey(
                                  item.id ?? item.assetId ?? item.uri ?? 'idx-$index',
                                );

                                return _GridTile(
                                  key: key,
                                  item: item,
                                  selected: selected,
                                  // CHECKBOXES ONLY WHEN IN SELECTION (manual, long-press)
                                  showCheckbox: inSelection,
                                  onTap: () {
                                    if (inSelection) {
                                      _toggleSelect(item.id);
                                    } else {
                                      final gi = indexByKey[_keyFor(item)] ?? index;
                                      context.push(
                                        '/viewer',
                                        extra: ViewerArgs(
                                          items: allFlat,
                                          index: gi,
                                        ),
                                      );
                                    }
                                  },
                                  onLong: () => _toggleSelect(item.id),
                                  onCheckToggle: () => _toggleSelect(item.id),
                                  onFavToggle: (v) async {
                                    if (item.id != null) {
                                      await IsarService()
                                          .toggleFavorite(item.id!, v);
                                    }
                                  },
                                );
                              },
                              childCount: section.items.length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                            ),
                          ),
                        )
                      else
                        SliverList.separated(
                          itemCount: section.items.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (context, index) {
                            final item = section.items[index];
                            final selected =
                                item.id != null && _selected.contains(item.id);
                            return _ListRow(
                              item: item,
                              selected: selected,
                              // CHECKBOXES ONLY WHEN IN SELECTION
                              showCheckbox: inSelection,
                              onTap: () {
                                if (inSelection) {
                                  _toggleSelect(item.id);
                                } else {
                                  final gi = indexByKey[_keyFor(item)] ?? index;
                                  context.push(
                                    '/viewer',
                                    extra: ViewerArgs(
                                      items: allFlat,
                                      index: gi,
                                    ),
                                  );
                                }
                              },
                              onLong: () => _toggleSelect(item.id),
                              onCheckToggle: () => _toggleSelect(item.id),
                              onFavToggle: (v) async {
                                if (item.id != null) {
                                  await IsarService()
                                      .toggleFavorite(item.id!, v);
                                }
                              },
                            );
                          },
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),

                // Selection bar (floating) — appears only after long-press
                if (inSelection)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _SelectionBar(
                      count: _selected.length,
                      type: widget.type,
                      onClear: _clearSelection,
                      onShare: _shareSelected,
                      onSelectAll: _selectAllVisible,
                      onDeselectAll: _clearSelection,
                      onFavourite: () async {
                        final ids = _selected.toList();
                        for (final id in ids) {
                          final e = await IsarService().db.mediaEntrys.get(id);
                          if (e != null) {
                            await IsarService().toggleFavorite(id, !e.favorite);
                          }
                        }
                        setState(_selected.clear);
                      },
                      onTrash:
                          widget.type == _AlbumType.trash ? null : _bulkTrashWithUndo,
                      onRestore: widget.type == _AlbumType.trash
                          ? _bulkRestoreWithUndo
                          : null,
                      onDelete: widget.type == _AlbumType.trash
                          ? () async {
                              final ids = _selected.toList();
                              for (final id in ids) {
                                final e = await IsarService().db.mediaEntrys.get(id);
                                if (e == null) continue;
                                if (e.assetId != null && e.assetId!.isNotEmpty) {
                                  await MediaDelete.permanentDelete(assetId: e.assetId);
                                } else if (e.uri.isNotEmpty) {
                                  await MediaDelete.permanentDelete(uri: e.uri);
                                } else {
                                  await IsarService().deletePermanently(id: id);
                                }
                              }
                              setState(_selected.clear);
                            }
                          : null,
                      onBackup: cloudOn
                          ? () async {
                              final repo = CloudSyncRepositoryImpl(
                                auth: AwsAuth(),
                                storage: AwsStorage(),
                                isar: IsarService(),
                              );
                              final ids = _selected.toList();
                              final items = <MediaItem>[];
                              for (final id in ids) {
                                final e = await IsarService().db.mediaEntrys.get(id);
                                if (e != null) items.add(MediaMapper.toEntity(e));
                              }
                              await repo.backupAll(items);
                              setState(_selected.clear);
                            }
                          : null,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleSelect(int? id) {
    if (id == null) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _bulkTrashWithUndo() async {
    final ids = _selected.toList();
    for (final id in ids) {
      await IsarService().moveToTrash(id);
    }
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved ${ids.length} item(s) to Trash'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            for (final id in ids) {
              await IsarService().restoreFromTrash(id);
            }
          },
        ),
      ),
    );
  }

  Future<void> _bulkRestoreWithUndo() async {
    final ids = _selected.toList();
    for (final id in ids) {
      await IsarService().restoreFromTrash(id);
    }
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored ${ids.length} item(s)'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            for (final id in ids) {
              await IsarService().moveToTrash(id);
            }
          },
        ),
      ),
    );
  }
}

// ====== Modern tiles/rows with checkbox support ======

class _GridTile extends StatelessWidget {
  final MediaItem item;
  final bool selected;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onLong;
  final VoidCallback onCheckToggle;
  final ValueChanged<bool> onFavToggle;

  const _GridTile({
    super.key,
    required this.item,
    required this.selected,
    required this.showCheckbox,
    required this.onTap,
    required this.onLong,
    required this.onCheckToggle,
    required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == 'video';
    final f = item.uri != null ? File(item.uri!) : null;
    final heroTag = 'm-${item.id ?? item.assetId ?? item.uri ?? 'x'}';

    Widget thumb;
    if (item.assetId != null) {
      thumb = SystemThumb(
        key: ValueKey('sys-${item.assetId}'),
        assetId: item.assetId!,
        isVideo: isVideo,
      );
    } else if (f != null && f.existsSync()) {
      final k = ValueKey('file-${f.path}');
      thumb = isVideo
          ? VideoThumb(key: k, path: f.path)
          : Image.file(f, key: k, fit: BoxFit.cover);
    } else {
      thumb = Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade500,
          size: 36,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLong,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: heroTag, child: thumb),
                // subtle bottom gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: item.id == null ? null : () => onFavToggle(!item.favorite),
                    icon: Icon(
                      item.favorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showCheckbox)
          Positioned(
            right: 6,
            top: 6,
            child: InkWell(
              onTap: onCheckToggle,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(2),
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onCheckToggle(),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  checkColor: Colors.black,
                  activeColor: Colors.white,
                ),
              ),
            ),
          ),
        if (selected && !showCheckbox) Container(color: Colors.black26),
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  final MediaItem item;
  final bool selected;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onLong;
  final VoidCallback onCheckToggle;
  final ValueChanged<bool> onFavToggle;

  const _ListRow({
    super.key,
    required this.item,
    required this.selected,
    required this.showCheckbox,
    required this.onTap,
    required this.onLong,
    required this.onCheckToggle,
    required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == 'video';
    final f = item.uri != null ? File(item.uri!) : null;
    final heroTag = 'm-${item.id ?? item.assetId ?? item.uri ?? 'x'}';

    Widget leading;
    if (item.assetId != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 72,
          height: 56,
          child: SystemThumb(
            key: ValueKey('sys-${item.assetId}'),
            assetId: item.assetId!,
            isVideo: isVideo,
          ),
        ),
      );
    } else if (f != null && f.existsSync()) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 72,
          height: 56,
          child: isVideo
              ? VideoThumb(key: ValueKey('file-${f.path}'), path: f.path)
              : Image.file(f, fit: BoxFit.cover),
        ),
      );
    } else {
      leading = Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.broken_image_outlined),
      );
    }

    final name = (() {
      if (item.assetId != null) return '${item.bucket} ${item.type}'.toUpperCase();
      final u = item.uri ?? '';
      return u.isEmpty ? '(item)' : File(u).uri.pathSegments.last;
    })();

    return InkWell(
      onTap: onTap,
      onLongPress: onLong,
      child: Container(
        color: selected ? Colors.black12 : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Hero(tag: heroTag, child: leading),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: [
                      _Pill(text: item.type.toUpperCase()),
                      if (item.bucket.isNotEmpty) _Pill(text: item.bucket),
                      if (item.tags.isNotEmpty)
                        _Pill(text: '${item.tags.length} tag(s)'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showCheckbox)
              Checkbox(
                value: selected,
                onChanged: (_) => onCheckToggle(),
              )
            else ...[
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: item.id == null ? null : () => onFavToggle(!item.favorite),
                icon: Icon(
                  item.favorite ? Icons.favorite : Icons.favorite_border,
                ),
              ),
              const SizedBox(width: 6),
              if (isVideo) const Icon(Icons.play_circle_fill, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final _AlbumType type;
  final VoidCallback onClear;
  final VoidCallback? onFavourite;
  final VoidCallback? onTrash;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final VoidCallback? onBackup;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onShare;

  const _SelectionBar({
    required this.count,
    required this.type,
    required this.onClear,
    this.onFavourite,
    this.onTrash,
    this.onRestore,
    this.onDelete,
    this.onBackup,
    this.onShare,
    this.onSelectAll,
    this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    final isTrash = type == _AlbumType.trash;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              '$count ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (onShare != null)
              IconButton(
                tooltip: 'Share',
                onPressed: onShare,
                icon: const Icon(Icons.share),
              ),
            if (onSelectAll != null)
              IconButton(
                tooltip: 'Select all',
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all),
              ),
            if (onDeselectAll != null)
              IconButton(
                tooltip: 'Deselect all',
                onPressed: onDeselectAll,
                icon:
                    const Icon(Icons.indeterminate_check_box_outlined),
              ),
            if (onFavourite != null)
              IconButton(
                tooltip: 'Favourite',
                onPressed: onFavourite,
                icon: const Icon(Icons.favorite),
              ),
            if (!isTrash && onTrash != null)
              IconButton(
                tooltip: 'Trash',
                onPressed: onTrash,
                icon: const Icon(Icons.delete_outline),
              ),
            if (isTrash && onRestore != null)
              IconButton(
                tooltip: 'Restore',
                onPressed: onRestore,
                icon: const Icon(Icons.restore_from_trash),
              ),
            if (isTrash && onDelete != null)
              IconButton(
                tooltip: 'Delete permanently',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever_outlined),
              ),
            IconButton(
              tooltip: 'Cancel',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
