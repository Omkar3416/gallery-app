import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class SystemThumb extends StatefulWidget {
  final String assetId;
  final bool isVideo;
  const SystemThumb({super.key, required this.assetId, required this.isVideo});

  @override
  State<SystemThumb> createState() => _SystemThumbState();
}

class _SystemThumbState extends State<SystemThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entity = await AssetEntity.fromId(widget.assetId);
    if (entity == null) return;
    final data = await entity.thumbnailDataWithSize(const ThumbnailSize(600, 600));
    if (!mounted) return;
    setState(() => _bytes = data);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(_bytes!, fit: BoxFit.cover),
        if (widget.isVideo)
          const Positioned(
            right: 8,
            bottom: 8,
            child: Icon(Icons.videocam_outlined),
          ),
      ],
    );
  }
}
