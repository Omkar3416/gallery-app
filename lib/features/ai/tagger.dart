/// WHAT: Common contract so we can plug different taggers (on-device / AWS).
/// WHY: Keeps UI/data layer agnostic; you can later add AWS Rekognition
///      behind the same interface without touching screens.
abstract class Tagger {
  /// Returns a set of tags for a given media file/asset.
  ///
  /// [localPath]   - File path if you have it (imported items).
  /// [fileName]    - Last segment of path (or synthetic name for system asset).
  /// [bucket]      - Album/folder name (e.g., WhatsApp Images, Telegram).
  /// [type]        - 'image' | 'video'.
  /// [width/height]- Dimensions if available (used for 'portrait', 'screenshot', etc.).
  Future<List<String>> tagsFor({
    String? localPath,
    required String fileName,
    required String bucket,
    required String type,
    int? width,
    int? height,
  });
}
