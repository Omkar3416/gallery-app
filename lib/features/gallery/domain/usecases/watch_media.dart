import '../entities/media_item.dart';
import '../repositories/gallery_repository.dart';

class WatchMedia {
  final GalleryRepository repo;
  WatchMedia(this.repo);
  Stream<List<MediaItem>> call() => repo.watchAll();
}
