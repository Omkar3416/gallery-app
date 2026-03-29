import 'dart:io';
import 'package:path/path.dart' as p;
import 'tagger.dart';

/// WHAT: Zero-cost, privacy-friendly tagger that infers tags from
///       file name, album/bucket, media type, and aspect ratio.
/// WHY: Gives immediate value (tags, chips, smart albums) without cloud costs.
class OnDeviceTagger implements Tagger {
  static final RegExp _reScreenshot = RegExp(r'screenshot', caseSensitive: false);
  static final RegExp _reWhatsapp  = RegExp(r'whats?app', caseSensitive: false);
  static final RegExp _reTelegram  = RegExp(r'telegram', caseSensitive: false);
  static final RegExp _reDownload  = RegExp(r'download', caseSensitive: false);
  static final RegExp _reInstagram = RegExp(r'insta', caseSensitive: false);
  static final RegExp _reFacebook  = RegExp(r'facebook|fb_', caseSensitive: false);
  static final RegExp _reCameraN   = RegExp(r'IMG_|VID_|PXL_|DSC_', caseSensitive: false);
  static final RegExp _reScreenFn  = RegExp(r'screenshot|screen-shot|screen_shot', caseSensitive: false);

  @override
  Future<List<String>> tagsFor({
    String? localPath,
    required String fileName,
    required String bucket,
    required String type,
    int? width,
    int? height,
  }) async {
    final tags = <String>{};

    // Type tags
    tags.add(type); // 'image' or 'video'

    // Bucket hints
    final b = bucket.toLowerCase();
    if (_reWhatsapp.hasMatch(b)) tags.addAll({'whatsapp', 'messaging'});
    if (_reTelegram.hasMatch(b)) tags.addAll({'telegram', 'messaging'});
    if (_reDownload.hasMatch(b)) tags.add('downloads');
    if (_reScreenshot.hasMatch(b)) tags.add('screenshot');
    if (_reInstagram.hasMatch(b)) tags.add('instagram');
    if (_reFacebook.hasMatch(b)) tags.add('facebook');

    // Filename hints
    final fn = fileName.toLowerCase();
    if (_reScreenFn.hasMatch(fn)) tags.add('screenshot');
    if (_reCameraN.hasMatch(fn)) tags.add('camera');

    // Orientation / shape
    if ((width ?? 0) > 0 && (height ?? 0) > 0) {
      if (width == height) tags.add('square');
      if ((width! / height!) >= 2.0) tags.add('panorama');
      if (height > width) tags.add('portrait'); else tags.add('landscape');
      // Very tall aspect ratios are usually mobile screenshots
      if (!tags.contains('screenshot') && (height / width) > 1.9) tags.add('screenshot');
    }

    // File extension tags (if path known)
    final ext = p.extension(fileName).toLowerCase();
    if (ext.isNotEmpty) tags.add(ext.replaceFirst('.', 'ext-')); // e.g., ext-jpg, ext-mp4

    // Keep small, stable set
    return tags.toList()..sort();
  }
}
