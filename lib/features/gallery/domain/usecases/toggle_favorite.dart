import '../repositories/gallery_repository.dart';

class ToggleFavorite {
  final GalleryRepository repo;
  ToggleFavorite(this.repo);
  Future<void> call(int id, bool value) => repo.toggleFavorite(id, value);
}
