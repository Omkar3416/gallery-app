import 'package:isar/isar.dart';

import '../../../../services/isar/schemas/media_entry.dart';
import '../../domain/entities/media_item.dart';

class MediaMapper {
  static MediaItem toEntity(MediaEntry e) => MediaItem(
        id: e.id,
        uri: e.uri.isEmpty ? null : e.uri,
        assetId: e.assetId,
        type: e.type,
        origin: e.origin,
        bucket: e.bucket,
        createdAt: e.createdAt,
        tags: List<String>.from(e.tags),
        favorite: e.favorite,
        backedUp: e.backedUp,
        cloudKey: e.cloudKey,
        trashed: e.trashed,
        trashedAt: e.trashedAt,
        missing: e.missing,
      );

  static MediaEntry fromEntity(MediaItem i) {
    final e = MediaEntry()
      ..id = i.id ?? Isar.autoIncrement
      ..uri = (i.uri ?? '')
      ..assetId = i.assetId
      ..type = i.type
      ..origin = i.origin
      ..bucket = i.bucket
      ..createdAt = i.createdAt
      ..tags = List<String>.from(i.tags)
      ..favorite = i.favorite
      ..backedUp = i.backedUp
      ..cloudKey = i.cloudKey
      ..trashed = i.trashed
      ..trashedAt = i.trashedAt
      ..missing = i.missing;
    return e;
  }
}
