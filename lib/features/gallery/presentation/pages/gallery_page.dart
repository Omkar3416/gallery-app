import 'dart:io';
import 'dart:ui' as ui; // for BackdropFilter (glass)
import 'package:flutter/material.dart';
import 'package:gallery_app/core/widgets/app_nav.dart';
import 'package:gallery_app/features/gallery/presentation/pages/viewer_session.dart';
import 'package:gallery_app/services/isar/schemas/media_entry.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../core/utils/date_groups.dart';

import '../../../gallery/domain/entities/media_item.dart';
import '../../../gallery/domain/usecases/add_media_from_paths.dart';
import '../../../gallery/domain/usecases/watch_media.dart';
import '../../../gallery/domain/usecases/toggle_favorite.dart';

import '../../../gallery/data/datasources/local_gallery_source.dart';
import '../../../gallery/data/repositories/gallery_repository_impl.dart';
import '../../../gallery/data/mappers/media_mapper.dart';

import '../../../../services/isar/isar_service.dart';
import '../../../../features/ai/on_device_tagger.dart';

import '../widgets/video_thumb.dart';
import '../widgets/system_thumb.dart';

import '../../../../features/backup/data/cloud_sync_repository_impl.dart';
import '../../../../services/aws/auth/aws_auth.dart';
import '../../../../services/aws/storage/aws_storage.dart';
import '../../../../core/config/app_settings.dart';
import 'viewer_args.dart';

enum _ViewMode { grid, list }

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late final WatchMedia _watch;
  late final AddMediaFromPaths _add;
  late final ToggleFavorite _toggle;
  final List<int> _visibleIds = [];

  String _query = '';
  final Set<String> _selectedTags = {};
  final _searchCtl = TextEditingController();

  // manual multi-select (enter via long-press)
  final _selectedIds = <int>{};
  bool get inSelection => _selectedIds.isNotEmpty;

  _ViewMode _mode = _ViewMode.grid;

  @override
  void initState() {
    super.initState();
    final repo = GalleryRepositoryImpl(
      local: LocalGallerySource(IsarService()),
      tagger: OnDeviceTagger(),
    );
    _watch = WatchMedia(repo);
    _add = AddMediaFromPaths(repo);
    _toggle = ToggleFavorite(repo);
  }

  // ---------- helpers ----------
  String _keyFor(MediaItem m) =>
      m.id?.toString() ?? m.assetId ?? m.uri ?? 'noid-${m.hashCode}';

  void _snack(
    String msg, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), action: action, duration: duration),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings();
    final showCloudUI = !s.isCloudLocked;
    final cloudOn = s.awsEnabled;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 8,
        title: inSelection
            ? Text('${_selectedIds.length} selected')
            : const Text('Gallery'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.65),
            ),
          ),
        ),
        actions: [
          if (inSelection) ...[
            IconButton(
              tooltip: 'Select all',
              onPressed: () => setState(() => _selectedIds.addAll(_visibleIds)),
              icon: const Icon(Icons.select_all),
            ),
            IconButton(
              tooltip: 'Deselect all',
              onPressed: () => setState(_selectedIds.clear),
              icon: const Icon(Icons.indeterminate_check_box_outlined),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: _shareSelected,
              icon: const Icon(Icons.share),
            ),
            IconButton(
              tooltip: 'Favourite',
              onPressed: _bulkFavouriteToggle,
              icon: const Icon(Icons.favorite),
            ),
            IconButton(
              tooltip: 'Trash',
              onPressed: _bulkTrash,
              icon: const Icon(Icons.delete_outline),
            ),
            if (cloudOn)
              IconButton(
                tooltip: 'Backup',
                onPressed: _bulkBackup,
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
            IconButton(
              tooltip: 'Cancel',
              onPressed: () => setState(_selectedIds.clear),
              icon: const Icon(Icons.close),
            ),
          ] else ...[
            // grid/list toggle
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ToggleButtons(
                isSelected: [_mode == _ViewMode.grid, _mode == _ViewMode.list],
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
            // quick nav / tools
            // IconButton(
            //   tooltip: 'Albums',
            //   onPressed: () => context.push('/albums'),
            //   icon: const Icon(Icons.photo_album_outlined),
            // ),
            if (showCloudUI)
              IconButton(
                tooltip: 'Backup',
                onPressed: () => context.push('/backup'),
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
            // IconButton(
            //   tooltip: 'Settings',
            //   onPressed: () => context.push('/settings'),
            //   icon: const Icon(Icons.settings),
            // ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _SearchBar(
              controller: _searchCtl,
              hint: 'Search by name or tag…',
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              onClear: () => setState(() {
                _query = '';
                _searchCtl.clear();
              }),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          int cols = Responsive.columnsForWidth(c.maxWidth).clamp(3, 10);

          return Padding(
            padding: const EdgeInsets.only(top: 64),
            child: StreamBuilder<List<MediaItem>>(
              stream: _watch(),
              builder: (context, snap) {
                final itemsAll = snap.data ?? const [];
                if (itemsAll.isEmpty) return _emptyState();

                // Tag universe
                final allTags = (itemsAll.expand(
                  (e) => e.tags,
                )).toSet().toList()..sort();

                // combined filters
                final filtered = itemsAll.where((i) {
                  final q = _query;
                  final name = (() {
                    if (i.assetId != null) {
                      return '${i.bucket} ${i.type}'.toLowerCase();
                    }
                    final u = i.uri ?? '';
                    return u.isEmpty
                        ? ''
                        : File(u).uri.pathSegments.last.toLowerCase();
                  })();
                  final tagsL = i.tags.map((e) => e.toLowerCase());
                  final matchesText =
                      q.isEmpty ||
                      name.contains(q) ||
                      tagsL.any((t) => t.contains(q));
                  final matchesTags =
                      _selectedTags.isEmpty ||
                      _selectedTags.every((t) => i.tags.contains(t));
                  return matchesText && matchesTags;
                }).toList();

                if (filtered.isEmpty) {
                  return Column(
                    children: [
                      _TagRow(
                        allTags: allTags,
                        selected: _selectedTags,
                        onToggle: (t) => setState(() {
                          if (_selectedTags.contains(t)) {
                            _selectedTags.remove(t);
                          } else {
                            _selectedTags.add(t);
                          }
                        }),
                      ),
                      const Divider(height: 0),
                      Expanded(
                        child: _emptyState(
                          message: 'No results match your filters',
                        ),
                      ),
                    ],
                  );
                }

                // group by date
                final sections = groupByFriendlyDate(filtered);

                // visible IDs for Select All
                _visibleIds
                  ..clear()
                  ..addAll(
                    filtered.where((e) => e.id != null).map((e) => e.id!),
                  );

                // flattened list + index map for viewer
                final List<MediaItem> allFlat = [
                  for (final s in sections) ...s.items,
                ];
                final Map<String, int> indexByKey = {
                  for (int i = 0; i < allFlat.length; i++)
                    _keyFor(allFlat[i]): i,
                };

                return Column(
                  children: [
                    _TagRow(
                      allTags: allTags,
                      selected: _selectedTags,
                      onToggle: (t) => setState(() {
                        if (_selectedTags.contains(t)) {
                          _selectedTags.remove(t);
                        } else {
                          _selectedTags.add(t);
                        }
                      }),
                    ),
                    const Divider(height: 0),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          for (final section in sections) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  section.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ),
                            if (_mode == _ViewMode.grid)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cols,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 1,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = section.items[index];
                                    final selected =
                                        item.id != null &&
                                        _selectedIds.contains(item.id);
                                    final stableKey = ValueKey(
                                      item.id ??
                                          item.assetId ??
                                          item.uri ??
                                          'idx-$index',
                                    );
                                    return _GridTile(
                                      key: stableKey,
                                      item: item,
                                      selected: selected,
                                      showCheckbox: inSelection, // NEW
                                      onTap: () {
                                        if (inSelection) {
                                          _toggleSelect(item.id);
                                        } else {
                                          final gi =
                                              indexByKey[_keyFor(item)] ?? 0;
                                          // context.push(
                                          //   '/viewer',
                                          //   extra: ViewerArgs(
                                          //     items: allFlat,
                                          //     index: gi,
                                          //   ),
                                          // );
                                          ViewerSession.items = allFlat;
                                          context.push('/viewer/$gi');
                                        }
                                      },
                                      onLong: () => _toggleSelect(
                                        item.id,
                                      ), // enter selection
                                      onCheckToggle: () =>
                                          _toggleSelect(item.id), // NEW
                                      onFavToggle: (v) {
                                        if (item.id != null)
                                          _toggle(item.id!, v);
                                      },
                                    );
                                  }, childCount: section.items.length),
                                ),
                              )
                            else
                              SliverList.separated(
                                itemCount: section.items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 0),
                                itemBuilder: (context, index) {
                                  final item = section.items[index];
                                  final selected =
                                      item.id != null &&
                                      _selectedIds.contains(item.id);
                                  return _ListRow(
                                    item: item,
                                    selected: selected,
                                    showCheckbox: inSelection, // NEW
                                    onTap: () {
                                      if (inSelection) {
                                        _toggleSelect(item.id);
                                      } else {
                                        final gi =
                                            indexByKey[_keyFor(item)] ?? 0;
                                        // context.push(
                                        //   '/viewer',
                                        //   extra: ViewerArgs(
                                        //     items: allFlat,
                                        //     index: gi,
                                        //   ),
                                        // );
                                        ViewerSession.items = allFlat;
                                        context.push('/viewer/$gi');
                                      }
                                    },
                                    onLong: () => _toggleSelect(item.id),
                                    onCheckToggle: () =>
                                        _toggleSelect(item.id), // NEW
                                    onFavToggle: (v) {
                                      if (item.id != null) _toggle(item.id!, v);
                                    },
                                  );
                                },
                              ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: inSelection ? null : _fab(),
      bottomNavigationBar: const AppNavBar(current: AppTab.gallery),
    );
  }

  // ---------- bulk actions ----------
  void _toggleSelect(int? id) {
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkFavouriteToggle() async {
    final ids = _selectedIds.toList();
    for (final id in ids) {
      final e = await IsarService().db.mediaEntrys.get(id);
      if (e != null) await IsarService().toggleFavorite(id, !e.favorite);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _bulkTrash() async {
    final ids = _selectedIds.toList();
    for (final id in ids) {
      await IsarService().moveToTrash(id);
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    _snack(
      'Moved ${ids.length} item(s) to Trash',
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () async {
          for (final id in ids) {
            await IsarService().restoreFromTrash(id);
          }
        },
      ),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _bulkBackup() async {
    final repo = CloudSyncRepositoryImpl(
      auth: AwsAuth(),
      storage: AwsStorage(),
      isar: IsarService(),
    );
    final ids = _selectedIds.toList();
    final items = <MediaItem>[];
    for (final id in ids) {
      final e = await IsarService().db.mediaEntrys.get(id);
      if (e != null) items.add(MediaMapper.toEntity(e));
    }
    await repo.backupAll(items);
    if (mounted) setState(_selectedIds.clear);
  }

  // ---------- capture ----------
  Widget _fab() {
    return FloatingActionButton.extended(
      onPressed: _showCaptureSheet,
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Capture'),
    );
  }

  void _showCaptureSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.camera_alt_outlined,
                title: 'Take photo',
                subtitle: 'Open the camera and capture a new photo',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _capturePhoto();
                },
              ),
              _SheetAction(
                icon: Icons.videocam_outlined,
                title: 'Record video',
                subtitle: 'Capture up to 5 minutes',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _recordVideo();
                },
              ),
              const Divider(height: 18),
              _SheetAction(
                icon: Icons.photo_library_outlined,
                title: 'Import photos from gallery',
                subtitle: 'Pick multiple images',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickImages();
                },
              ),
              _SheetAction(
                icon: Icons.video_collection_outlined,
                title: 'Import video from gallery',
                subtitle: 'Pick a single video',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickVideo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    if (!await MediaPermissions.requestForImages()) return;
    final picker = ImagePicker();
    final picks = await picker.pickMultiImage();
    if (picks.isEmpty) return;
    final paths = picks.map((x) => x.path).toList();
    await _add(paths, 'image');
    if (!mounted) return;
    _snack('Added ${paths.length} image(s)');
  }

  Future<void> _pickVideo() async {
    if (!await MediaPermissions.requestForVideos()) return;
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    await _add([x.path], 'video');
    if (!mounted) return;
    _snack('Added 1 video');
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(source: ImageSource.camera);
    if (shot == null) return;
    await _add([shot.path], 'image');
    if (!mounted) return;
    _snack('Captured photo added');
  }

  Future<void> _recordVideo() async {
    final picker = ImagePicker();
    final clip = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (clip == null) return;
    await _add([clip.path], 'video');
    if (!mounted) return;
    _snack('Recorded video added');
  }

  // ---------- misc ----------
  Widget _emptyState({String message = 'Welcome to your gallery'}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 64),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Use “Capture” to take photos/videos or import from your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showCaptureSheet,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add media'),
          ),
        ],
      ),
    ),
  );

  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;

    final isar = IsarService().db;
    final paths = <String>[];

    for (final id in _selectedIds) {
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

    if (paths.isEmpty) {
      if (!mounted) return;
      _snack('No accessible files to share');
      return;
    }

    await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
  }
}

// ======= UI bits =======

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        isDense: true,
      ),
    );
  }
}

// Grid/List tiles with checkbox support (checkbox shows only in selection mode)
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLong,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: heroTag, child: thumb),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(.24),
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
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _FavButton(
                    isFav: item.favorite,
                    onToggle: onFavToggle,
                  ),
                ),
                if (item.tags.isNotEmpty)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _TagBubble(count: item.tags.length),
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
        if (selected && !showCheckbox)
          const Positioned(
            right: 8,
            top: 8,
            child: Icon(Icons.check_circle, size: 22, color: Colors.white),
          ),
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
      if (item.assetId != null)
        return '${item.bucket} ${item.type}'.toUpperCase();
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
                      // if (item.tags.isNotEmpty)
                      //   _Pill(text: '${item.tags.length} tag(s)'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showCheckbox)
              Checkbox(value: selected, onChanged: (_) => onCheckToggle())
            else ...[
              _FavButton(isFav: item.favorite, onToggle: onFavToggle),
              const SizedBox(width: 6),
              if (isVideo) const Icon(Icons.play_circle_fill, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// tiny favorite control
class _FavButton extends StatefulWidget {
  final bool isFav;
  final ValueChanged<bool> onToggle;
  const _FavButton({required this.isFav, required this.onToggle, super.key});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  late bool _fav = widget.isFav;
  @override
  void didUpdateWidget(covariant _FavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFav != widget.isFav) _fav = widget.isFav;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        setState(() => _fav = !_fav);
        widget.onToggle(_fav);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          _fav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(_fav),
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TagBubble extends StatelessWidget {
  final int count;
  const _TagBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.55),
        borderRadius: BorderRadius.circular(999),
      ),
      // child: Padding(
      //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      //   child: Row(
      //     mainAxisSize: MainAxisSize.min,
      //     children: [
      //       const Icon(Icons.tag, color: Colors.white, size: 14),
      //       const SizedBox(width: 4),
      //       Text(
      //         '$count',
      //         style: const TextStyle(color: Colors.white, fontSize: 12),
      //       ),
      //     ],
      //   ),
      // ),
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

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(radius: 22, child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

// tag strip
class _TagRow extends StatelessWidget {
  final List<String> allTags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _TagRow({
    required this.allTags,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (allTags.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.label_outline, size: 18),
          const SizedBox(width: 8),
          ...allTags.map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(t),
                selected: selected.contains(t),
                onSelected: (_) => onToggle(t),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
