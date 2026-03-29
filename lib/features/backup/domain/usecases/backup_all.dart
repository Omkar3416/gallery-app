// lib/features/backup/domain/usecases/backup_all.dart
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';
import '../cloud_sync_repository.dart';

class BackupAll {
  final CloudSyncRepository repo;
  BackupAll(this.repo);
  Future<int> call(List<MediaItem> items, {int? maxCount}) =>
      repo.backupAll(items, maxCount: maxCount);
}
