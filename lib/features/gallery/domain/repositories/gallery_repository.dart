import '../entities/media_item.dart';

abstract class GalleryRepository {
  Stream<List<MediaItem>> watchAll();
  Future<int> addFromLocalPath(String path, String type, {List<String> tags = const []});
  Future<void> toggleFavorite(int id, bool value);
}
