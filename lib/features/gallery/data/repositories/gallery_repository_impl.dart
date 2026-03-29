import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../../core/utils/file_io.dart' show FileIO;
import '../../../../features/ai/tagger.dart';          // <- use the interface
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../datasources/local_gallery_source.dart';
import '../mappers/media_mapper.dart';

class GalleryRepositoryImpl implements GalleryRepository {
  final LocalGallerySource local;
  final Tagger tagger;                                  // <- depend on Tagger

  GalleryRepositoryImpl({required this.local, required this.tagger});

  @override
  Stream<List<MediaItem>> watchAll() {
    return local.watchAll().map((list) => list.map(MediaMapper.toEntity).toList());
  }

  @override
  Future<int> addFromLocalPath(String path, String type, {List<String> tags = const []}) async {
    // Ensure the file is in app storage (copy if needed)
    final file = File(path);
    final ensured = await FileIO.ensureInAppDir(file);

    // 🔑 Pass required named params expected by Tagger.tagsFor
    final autoTags = await tagger.tagsFor(
      localPath: ensured.path,
      fileName: p.basename(ensured.path),
      bucket: 'Imported',                               // matches LocalGallerySource.add
      type: type,                                       // 'image' | 'video'
      // width/height optional; skip to keep it fast
    );

    // merge unique tags
    final mergedTags = {...tags, ...autoTags}.toList();

    return local.add(
      ensured.path,
      type,
      tags: mergedTags,
      createdAt: await FileIO.createdAtMillis(ensured),
    );
  }

  @override
  Future<void> toggleFavorite(int id, bool value) => local.toggleFavorite(id, value);
}
