import '../repositories/gallery_repository.dart';

class AddMediaFromPaths {
  final GalleryRepository repo;
  AddMediaFromPaths(this.repo);

  /// Accepts absolute paths and a type ('image' | 'video')
  Future<List<int>> call(List<String> paths, String type, {List<String> tags = const []}) async {
    final ids = <int>[];
    for (final p in paths) {
      final id = await repo.addFromLocalPath(p, type,tags: tags);
      ids.add(id);
    }
    return ids;
  }
}
