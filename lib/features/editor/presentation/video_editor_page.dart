import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_app/features/ai/on_device_tagger.dart';
import 'package:gallery_app/features/gallery/data/datasources/local_gallery_source.dart';
import 'package:gallery_app/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';
import 'package:gallery_app/features/gallery/domain/usecases/add_media_from_paths.dart';
import 'package:gallery_app/services/isar/isar_service.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoEditorPage extends StatefulWidget {
  final MediaItem item;
  const VideoEditorPage({super.key, required this.item});

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage> {
  static const _chan = MethodChannel('native_video_editor');

  VideoPlayerController? _vp;
  Duration _duration = Duration.zero;

  // Trim state
  double _start = 0; // seconds
  double _end   = 0; // seconds (0=until end -> we’ll assign to duration on init)

  // Rotate & mute
  int _deg = 0;      // 0/90/180/270
  bool _mute = false;

  bool _exporting = false;

  late final AddMediaFromPaths _add;

  @override
  void initState() {
    super.initState();
    _add = AddMediaFromPaths(
      GalleryRepositoryImpl(local: LocalGallerySource(IsarService()), tagger: OnDeviceTagger()),
    );
    _init();
  }

  Future<void> _init() async {
    File? file;
    if (widget.item.assetId != null) {
      final ent = await AssetEntity.fromId(widget.item.assetId!);
      file = await ent?.file;
    } else if (widget.item.uri?.isNotEmpty ?? false) {
      final f = File(widget.item.uri!);
      if (await f.exists()) file = f;
    }
    if (file == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video not found')));
      Navigator.pop(context);
      return;
    }

    final c = VideoPlayerController.file(file);
    await c.initialize();
    _duration = c.value.duration;
    _end = _duration.inSeconds.toDouble();
    await c.setLooping(true);
    await c.play();

    if (!mounted) return;
    setState(() => _vp = c);
  }

  @override
  void dispose() {
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vp = _vp;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Video'),
        actions: [
          IconButton(
            tooltip: 'Save copy',
            onPressed: (_exporting || vp == null) ? null : _export,
            icon: _exporting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
          )
        ],
      ),
      body: vp == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: vp.value.aspectRatio == 0 ? 16 / 9 : vp.value.aspectRatio,
                  child: VideoPlayer(vp),
                ),
                const SizedBox(height: 8),

                // Trim range
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Trim'),
                          const Spacer(),
                          Text('${_start.toStringAsFixed(1)}s  →  ${_end.toStringAsFixed(1)}s'),
                        ],
                      ),
                      RangeSlider(
                        values: RangeValues(_start, _end),
                        min: 0,
                        max: _duration.inSeconds.toDouble(),
                        divisions: (_duration.inSeconds).clamp(1, 600),
                        labels: RangeLabels(
                          '${_start.toStringAsFixed(1)}s',
                          '${_end.toStringAsFixed(1)}s',
                        ),
                        onChanged: (r) => setState(() {
                          _start = r.start;
                          _end = r.end;
                        }),
                      ),
                    ],
                  ),
                ),

                // Rotate / Mute
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Rotate'),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 8,
                        children: [0, 90, 180, 270].map((d) {
                          final sel = _deg == d;
                          return ChoiceChip(
                            label: Text('$d°'),
                            selected: sel,
                            onSelected: (_) => setState(() => _deg = d),
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Text('Mute'),
                          Switch(value: _mute, onChanged: (v) => setState(() => _mute = v)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
    );
  }

  Future<void> _export() async {
    final vp = _vp!;
    setState(() => _exporting = true);

    try {
      // Resolve input path again (safe)
      File? inFile;
      if (widget.item.assetId != null) {
        final ent = await AssetEntity.fromId(widget.item.assetId!);
        inFile = await ent?.file;
      } else if (widget.item.uri?.isNotEmpty ?? false) {
        final f = File(widget.item.uri!);
        if (await f.exists()) inFile = f;
      }
      if (inFile == null) throw 'Input file missing';

      final base = await IsarService().appDir;
      final outDir = Directory(p.join(base.path, 'Edited'));
      await outDir.create(recursive: true);
      final outPath = p.join(outDir.path, 'VID_${DateTime.now().millisecondsSinceEpoch}_edited.mp4');

      // Call native Media3 exporter
      final res = await _chan.invokeMethod<String>('export', {
        'inputPath': inFile.path,
        'outputPath': outPath,
        'startMs'   : (_start * 1000).round(),
        'endMs'     : (_end   * 1000).round(),
        'mute'      : _mute,
        'rotateDegrees': _deg,
        // full frame crop (you can later pass normalized crop rect if you add UI)
        'cropL': 0.0, 'cropT': 0.0, 'cropR': 1.0, 'cropB': 1.0,
      });

      if (res == null || !File(outPath).existsSync()) {
        throw 'Export failed';
      }

      // Index the new copy in Isar
      await _add([outPath], 'video');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved edited video as copy')),
      );
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
