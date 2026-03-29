import 'dart:io';
import 'package:flutter/services.dart';

class NativeVideoEditor {
  static const _ch = MethodChannel('native_video_editor');

  static Future<String> export({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs, // 0 = no end clip
    required double cropL, // 0..1
    required double cropT,
    required double cropR,
    required double cropB,
    required int rotateDegrees,
    required bool mute,
    String? watermarkText,
    String? filter, // 'none' | 'bw' | 'sepia' | 'warm'
    String? soundtrackPath,
  }) async {
    if (!Platform.isAndroid) {
      throw 'Video export is implemented for Android only (Media3)';
    }
    final res = await _ch.invokeMethod<String>('export', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'startMs': startMs,
      'endMs': endMs,
      'cropL': cropL,
      'cropT': cropT,
      'cropR': cropR,
      'cropB': cropB,
      'rotateDegrees': rotateDegrees,
      'mute': mute,
      'watermarkText': watermarkText,
      'filter': filter == 'none' ? null : filter,
      'soundtrackPath': soundtrackPath,
    });
    if (res == null) throw 'Export failed';
    return res;
  }
}
