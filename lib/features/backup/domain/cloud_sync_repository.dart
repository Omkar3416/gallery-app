// lib/features/backup/domain/cloud_sync_repository.dart
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';

abstract class CloudSyncRepository {
  Future<bool> backup(MediaItem item);
  Future<int> backupAll(List<MediaItem> items, {int? maxCount});
}
