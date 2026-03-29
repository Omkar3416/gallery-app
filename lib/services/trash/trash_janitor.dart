import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/schemas/media_entry.dart';
import '../media_indexer/media_delete.dart';

class PurgeResult {
  final int examined;
  final int deleted;
  final int failed;
  const PurgeResult({required this.examined, required this.deleted, required this.failed});
}

class TrashJanitor {
  /// Permanently deletes items in Trash older than [days].
  /// - For system assets: uses PhotoManager delete (removes from device library).
  /// - For imported files: deletes the file path.
  /// - If no backing file exists: deletes the DB row.
  static Future<PurgeResult> emptyOlderThanDays(int days) async {
    final isar = IsarService().db;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    final all = await isar.mediaEntrys.where().findAll();
    final targets = all.where((e) => e.trashed && (e.trashedAt ?? e.createdAt) < cutoff).toList();

    int deleted = 0;
    int failed = 0;

    for (final e in targets) {
      bool ok = false;
      if (e.assetId != null) {
        ok = await MediaDelete.permanentDelete(assetId: e.assetId);
      } else if (e.uri.isNotEmpty) {
        ok = await MediaDelete.permanentDelete(uri: e.uri);
      } else {
        await IsarService().deletePermanently(id: e.id);
        ok = true;
      }
      if (ok) deleted++; else failed++;
    }

    return PurgeResult(examined: targets.length, deleted: deleted, failed: failed);
  }
}
