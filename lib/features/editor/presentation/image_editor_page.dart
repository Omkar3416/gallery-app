import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gallery_app/features/ai/on_device_tagger.dart';
import 'package:gallery_app/features/gallery/data/datasources/local_gallery_source.dart';
import 'package:gallery_app/features/gallery/data/repositories/gallery_repository_impl.dart';
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';
import 'package:gallery_app/features/gallery/domain/usecases/add_media_from_paths.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';


import '../../../../services/isar/isar_service.dart';

/// Opens the native editor UI immediately (no intermediate page),
/// saves an edited COPY to Documents/Edited, indexes it in Isar,
/// then pops back to the viewer.
class ImageEditorPage extends StatefulWidget {
  final MediaItem item;
  const ImageEditorPage({super.key, required this.item});

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  Uint8List? _bytes;
  String? _err;
  bool _opened = false;   // ensure we open editor only once
  bool _saving = false;

  late final AddMediaFromPaths _add;

  @override
  void initState() {
    super.initState();
    _add = AddMediaFromPaths(
      GalleryRepositoryImpl(
        local: LocalGallerySource(IsarService()),
        tagger: OnDeviceTagger(),
      ),
    );
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    try {
      File? f;

      // Try system asset first
      if (widget.item.assetId != null) {
        final ent = await AssetEntity.fromId(widget.item.assetId!);
        f = await ent?.file;
      }

      // Fallback to local file path
      if (f == null && (widget.item.uri?.isNotEmpty ?? false)) {
        final ff = File(widget.item.uri!);
        if (await ff.exists()) f = ff;
      }

      if (f == null) throw 'Cannot open image file';

      final b = await f.readAsBytes();
      if (!mounted) return;
      setState(() => _bytes = b);

      // Open the editor immediately on the next frame
      if (!_opened) {
        _opened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openEditor());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    }
  }

  Future<void> _openEditor() async {
    if (!mounted || _bytes == null) return;

    // Launch full ImageEditorPlus UI (crop, adjust, filters, brush, text, emoji, mosaic, blur…)
    final edited = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditor(image: _bytes!)),
    );

    if (!mounted) return;

    // User cancelled: just go back to the viewer
    if (edited == null) {
      Navigator.pop(context);
      return;
    }

    // Save edited copy + index it
    setState(() => _saving = true);

    final dir = await IsarService().appDir;           // ensure this getter exists (step 3 below)
    final outDir = Directory(p.join(dir.path, 'Edited'));
    await outDir.create(recursive: true);

    final name = 'IMG_${DateTime.now().millisecondsSinceEpoch}_edited.jpg';
    final outPath = p.join(outDir.path, name);
    await File(outPath).writeAsBytes(edited, flush: true);

    await _add([outPath], 'image');                   // non-destructive copy

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved edited copy')),
    );

    // Return to the viewer
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // This page only shows a tiny loader or error while the actual editor screen is pushed.
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Image')),
        body: Center(child: Text(_err!)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Image')),
      body: Center(
        child: (_bytes == null || _saving)
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(), // we auto-open editor; nothing else to show
      ),
    );
  }
}
