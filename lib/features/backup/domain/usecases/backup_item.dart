// lib/features/backup/domain/usecases/backup_item.dart
import 'package:gallery_app/features/gallery/domain/entities/media_item.dart';
import '../cloud_sync_repository.dart';

class BackupItem {
  final CloudSyncRepository repo;
  BackupItem(this.repo);
  Future<bool> call(MediaItem item) => repo.backup(item);
}
