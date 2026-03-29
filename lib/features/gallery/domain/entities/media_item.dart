class MediaItem {
  final int? id;
  final String? uri;
  final String? assetId;
  final String type;      // 'image' | 'video'
  final String origin;    // 'system' | 'imported'
  final String bucket;    // album/bucket name
  final int createdAt;
  final List<String> tags;
  final bool favorite;
  final bool backedUp;
  final String? cloudKey;
  final bool trashed;
  final int? trashedAt;
  final bool missing;

  const MediaItem({
    this.id,
    this.uri,
    this.assetId,
    required this.type,
    required this.origin,
    required this.bucket,
    required this.createdAt,
    this.tags = const [],
    this.favorite = false,
    this.backedUp = false,
    this.cloudKey,
    this.trashed = false,
    this.trashedAt,
    this.missing = false,
  });

  MediaItem copyWith({
    int? id,
    String? uri,
    String? assetId,
    String? type,
    String? origin,
    String? bucket,
    int? createdAt,
    List<String>? tags,
    bool? favorite,
    bool? backedUp,
    String? cloudKey,
    bool? trashed,
    int? trashedAt,
    bool? missing,
  }) {
    return MediaItem(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      assetId: assetId ?? this.assetId,
      type: type ?? this.type,
      origin: origin ?? this.origin,
      bucket: bucket ?? this.bucket,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      backedUp: backedUp ?? this.backedUp,
      cloudKey: cloudKey ?? this.cloudKey,
      trashed: trashed ?? this.trashed,
      trashedAt: trashedAt ?? this.trashedAt,
      missing: missing ?? this.missing,
    );
  }
}
