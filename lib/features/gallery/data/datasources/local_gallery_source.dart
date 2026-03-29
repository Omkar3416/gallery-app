import 'dart:async';
import '../../../../services/isar/isar_service.dart';
import '../../../../services/isar/schemas/media_entry.dart';

class LocalGallerySource {
  final IsarService isar;
  LocalGallerySource(this.isar);

  // 🔁 Use "not trashed" stream for main gallery
  Stream<List<MediaEntry>> watchAll() => isar.watchAllNotTrashed();

  Future<int> add(String uri, String type,
      {List<String> tags = const [], int? createdAt}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = MediaEntry()
      ..uri = uri
      ..type = type
      ..createdAt = createdAt ?? now
      ..origin = 'imported'
      ..bucket = 'Imported'
      ..tags = List<String>.from(tags)
      ..favorite = false
      ..backedUp = false
      ..cloudKey = null
      ..trashed = false
      ..trashedAt = null
      ..missing = false;
    return await isar.addMedia(entry);
  }

  Future<void> toggleFavorite(int id, bool v) async {
    await isar.toggleFavorite(id, v);
  }
}
