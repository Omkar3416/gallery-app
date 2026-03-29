import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumb extends StatefulWidget {
  final String path;
  const VideoThumb({super.key, required this.path});

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _gen();
  }

  Future<void> _gen() async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 70,
        timeMs: 1000,
      );
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _failed = true);
      } else {
        setState(() => _bytes = bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(child: Icon(Icons.movie_creation_outlined, size: 36));
    }
    if (_bytes == null) {
      return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Image.memory(_bytes!, fit: BoxFit.cover);
  }
}
