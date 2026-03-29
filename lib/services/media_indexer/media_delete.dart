import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import '../isar/isar_service.dart';

class MediaDelete {
  /// Move item to app Trash (soft delete)
  static Future<void> trashById(int id) => IsarService().moveToTrash(id);

  /// Permanently delete from device/system.
  /// Returns true only if the platform reports the asset/file was actually removed.
  static Future<bool> permanentDelete({String? assetId, String? uri}) async {
    bool ok = true;

    if (assetId != null) {
      // Returns the list of successfully deleted asset IDs.
      final List<String> deleted = await PhotoManager.editor.deleteWithIds([assetId]);
      ok = deleted.contains(assetId) || deleted.isNotEmpty;
      if (ok) {
        await IsarService().deletePermanently(assetId: assetId);
      }
    } else if (uri != null) {
      try {
        final f = File(uri);
        if (await f.exists()) {
          await f.delete();
        }
        await IsarService().deletePermanently(uri: uri);
      } catch (_) {
        ok = false;
      }
    }
    return ok;
  }
}
