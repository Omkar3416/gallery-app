// lib/features/backup/data/cloud_sync_repository_impl.dart
import 'dart:io';
import 'package:gallery_app/services/isar/schemas/media_entry.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_app/features/backup/domain/cloud_sync_repository.dart';
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';
import '../../../../services/aws/auth/aws_auth.dart';
import '../../../../services/aws/storage/aws_storage.dart';
import '../../../../services/isar/isar_service.dart';

class CloudSyncRepositoryImpl implements CloudSyncRepository {
  final AwsAuth auth;
  final AwsStorage storage;
  final IsarService isar;

  CloudSyncRepositoryImpl({
    required this.auth,
    required this.storage,
    required this.isar,
  });

  @override
  Future<bool> backup(MediaItem item) async {
    final file = await _resolveFile(item);
    if (file == null) return false;

    final key = await storage.uploadFile(file: file, extraTags: {
      'type': item.type,
      if (item.bucket.isNotEmpty) 'bucket': item.bucket,
    });


    // mark backed in your local DB
    final entry = await isar.db.mediaEntrys.get(item.id ?? -1);
    if (entry != null) {
      entry.backedUp = true;
      entry.cloudKey = key;
      await isar.db.writeTxn(() => isar.db.mediaEntrys.put(entry));
    }
    return true;
  }

    /// Same as [backup] but allows the caller to pass an [http.Client] that can be
  /// closed to cancel the upload mid-flight. Used by the Backup page UI.
  Future<bool> backupWithClient(MediaItem item, {http.Client? client}) async {
    final file = await _resolveFile(item);
    if (file == null) return false;

    final key = await storage.uploadFileWithClient(file: file, client: client);

    final e = await isar.db.mediaEntrys.get(item.id ?? -1);
    if (e != null) {
      e.backedUp = true;
      e.cloudKey = key;
      await isar.db.writeTxn(() async {
        await isar.db.mediaEntrys.put(e);
      });
    }
    return true;
  }

  @override
 Future<int> backupAll(List<MediaItem> items, {int? maxCount}) async {
    int ok = 0;
    final toBackup = maxCount != null ? items.take(maxCount) : items;
    for (final it in toBackup) {
      final done = await backup(it);
      if (done) ok++;
    }
    return ok;
  }

  Future<File?> _resolveFile(MediaItem item) async {
    // local URI?
    final u = item.uri ?? '';
    if (u.isNotEmpty) {
      final f = File(u);
      if (await f.exists()) return f;
    }
    // system media
    if (item.assetId != null) {
      final ent = await AssetEntity.fromId(item.assetId!);
      final f = await ent?.file;
      if (f != null && await f.exists()) return f;
    }
    return null;
  }
}
