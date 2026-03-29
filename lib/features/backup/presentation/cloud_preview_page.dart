// lib/features/backup/presentation/cloud_preview_page.dart
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../services/aws/storage/aws_storage.dart';

class CloudPreviewPage extends StatefulWidget {
  final String keyPath; // e.g. "uploads/IMG_123.jpg"
  const CloudPreviewPage({super.key, required this.keyPath});

  @override
  State<CloudPreviewPage> createState() => _CloudPreviewPageState();
}

class _CloudPreviewPageState extends State<CloudPreviewPage> {
  String? _url;
  String? _err;
  VideoPlayerController? _vp;
  ChewieController? _chewie;

  bool get _isVideo {
    final k = widget.keyPath.toLowerCase();
    return k.endsWith('.mp4') || k.endsWith('.mov') || k.endsWith('.m4v') || k.endsWith('.webm');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await AwsStorage().getDownloadUrl(key: widget.keyPath);
      if (!mounted) return;
      setState(() => _url = url);

      if (_isVideo) {
        final vp = VideoPlayerController.networkUrl(Uri.parse(url));
        await vp.initialize();
        final ch = ChewieController(
          videoPlayerController: vp,
          autoPlay: true,
          looping: false,
          allowPlaybackSpeedChanging: true,
          allowMuting: true,
        );
        if (!mounted) return;
        setState(() {
          _vp = vp;
          _chewie = ch;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
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
    final title = widget.keyPath.split('/').last;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _err != null
          ? Center(child: Text(_err!))
          : _url == null
              ? const Center(child: CircularProgressIndicator())
              : _isVideo
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _vp?.value.aspectRatio == 0 ? 16 / 9 : (_vp?.value.aspectRatio ?? 16 / 9),
                        child: Chewie(controller: _chewie!),
                      ),
                    )
                  : InteractiveViewer(child: Center(child: Image.network(_url!, fit: BoxFit.contain))),
    );
  }
}
