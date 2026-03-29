import 'package:isar/isar.dart';

part 'media_entry.g.dart';

/// Local-first media record (auto-indexed 'system' or manually 'imported')
@collection
class MediaEntry {
  Id id = Isar.autoIncrement;

  /// Used for 'imported' items (local file path). Empty for 'system' assets.
  String uri = '';

  /// Platform asset id (Android content id / iOS local id) for 'system' items.
  @Index(unique: true, replace: true)
  String? assetId;

  /// 'image' | 'video'
  late String type;

  /// 'system' | 'imported'
  String origin = 'imported';

  /// Album/bucket name (e.g., "WhatsApp Images", "Telegram", "Download", etc.)
  @Index(caseSensitive: false)
  String bucket = '';

  /// Unix epoch millis (creation)
  late int createdAt;

  /// AI tags
  List<String> tags = [];

  /// Local favorite
  bool favorite = false;

  /// Cloud backup markers
  bool backedUp = false;
  String? cloudKey;

  /// Soft-delete (Trash)
  bool trashed = false;
  int? trashedAt;

  /// If underlying asset/file is missing on device
  bool missing = false;
}
