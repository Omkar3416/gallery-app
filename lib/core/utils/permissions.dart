import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPermissions {
  static Future<bool> requestForImages() async {
    if (Platform.isIOS) {
      final s = await Permission.photos.request(); // iOS: Photo Library
      return s.isGranted || s.isLimited;
    }

    // ANDROID
    final sdk = await _sdkInt();
    if (sdk >= 33) {
      // Android 13+: READ_MEDIA_IMAGES
      final s = await Permission.photos.request();
      return s.isGranted || s.isLimited || s.isProvisional;
    } else {
      // <= Android 12: READ_EXTERNAL_STORAGE
      final s = await Permission.storage.request();
      return s.isGranted;
    }
  }

  static Future<bool> requestForVideos() async {
    if (Platform.isIOS) {
      final s = await Permission.videos.request(); // iOS: Videos Library
      return s.isGranted || s.isLimited;
    }

    // ANDROID
    final sdk = await _sdkInt();
    if (sdk >= 33) {
      // Android 13+: READ_MEDIA_VIDEO
      final s = await Permission.videos.request();
      return s.isGranted || s.isLimited || s.isProvisional;
    } else {
      // <= Android 12
      final s = await Permission.storage.request();
      return s.isGranted;
    }
  }

  static Future<int> _sdkInt() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }
}
