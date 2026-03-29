import 'dart:async';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../services/isar/isar_service.dart';
import '../../../services/isar/schemas/media_entry.dart';
import '../on_device_tagger.dart';
import '../tagger.dart';

/// WHAT: Background-friendly tagger that scans items lacking tags,
///       asks a Tagger for suggestions, and writes them back to Isar.
/// WHY: Not blocking UI; can be re-run on demand ("Retag all") or on new items.
class TaggingService {
  static final TaggingService _i = TaggingService._();
  TaggingService._();
  factory TaggingService() => _i;

  final Tagger _tagger = OnDeviceTagger();
  bool _running = false;

  /// Kick off a quick pass that tags only items with empty tags.
  Future<void> tagUntagged({int batchSize = 200}) async {
    if (_running) return;
    _running = true;
    try {
      final isar = IsarService().db;
      final all = await isar.mediaEntrys.where().findAll();
      final targets = all.where((e) => !e.trashed && (e.tags.isEmpty)).toList();

      int i = 0;
      for (final e in targets) {
        await _tagOne(e);
        i++;
        if (i % 50 == 0) {
          // yield to UI every 50 items
          await Future.delayed(Duration(milliseconds: 1));
        }
        if (i >= batchSize) break;
      }
    } finally {
      _running = false;
    }
  }

  /// Full retag (use from Settings). Replaces tags for all non-trashed items.
  Future<void> retagAll() async {
    if (_running) return;
    _running = true;
    try {
      final isar = IsarService().db;
      final all = await isar.mediaEntrys.where().findAll();
      for (final e in all.where((x) => !x.trashed)) {
        await _tagOne(e, replace: true);
        await Future.delayed(Duration.zero);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _tagOne(MediaEntry e, {bool replace = false}) async {
    // Get dimensions & filename
    int? w, h;
    String fileName = 'media';
    String? localPath;

    if (e.assetId != null) {
      final ent = await AssetEntity.fromId(e.assetId!);
      if (ent != null) {
        w = ent.width;
        h = ent.height;
        fileName = ent.title ?? 'media';
        final f = await ent.file;
        localPath = f?.path;
      }
    } else if (e.uri.isNotEmpty) {
      final f = File(e.uri);
      fileName = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'media';
      // Width/height are unknown for imported unless you decode; we skip decode for speed.
      localPath = e.uri;
    }

    final tags = await _tagger.tagsFor(
      localPath: localPath,
      fileName: fileName,
      bucket: e.bucket,
      type: e.type,
      width: w,
      height: h,
    );

    await IsarService().setTags(e.id, tags, replace: replace);
  }
}
