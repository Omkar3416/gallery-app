import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:isar/isar.dart'; // <-- needed for Isar type
import '../isar/isar_service.dart';
import '../isar/schemas/media_entry.dart';

class MediaIndexer {
  static final MediaIndexer _i = MediaIndexer._();
  MediaIndexer._();
  factory MediaIndexer() => _i;

  ValueChanged<MethodCall>? _callback;
  bool _running = false;
  Timer? _debounce;

  /// Fast, non-blocking startup:
  /// 1) seeds the UI quickly (first page of the first album)
  /// 2) then background full scan
  /// 3) listens to library changes and debounces re-scans
  Future<void> startFast() async {
    if (_running) return;

    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      debugPrint('[MediaIndexer] Photos permission not granted.');
      return;
    }

    _running = true;

    // Kick off a quick seed (no await -> UI not blocked)
    Future.microtask(() async {
      try {
        await _seedScan();
      } catch (e, st) {
        debugPrint('[MediaIndexer] seedScan error: $e\n$st');
      }
      // After seed, continue with a full background scan
      Future(() async {
        try {
          await _fullScan();
        } catch (e, st) {
          debugPrint('[MediaIndexer] fullScan error: $e\n$st');
        }
      });
    });

    // Listen for library changes; debounce to avoid storms
    _callback ??= (MethodCall _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), () {
        Future(() async {
          try {
            await _incrementalScan();
          } catch (e, st) {
            debugPrint('[MediaIndexer] incremental error: $e\n$st');
          }
        });
      });
    };
    PhotoManager.addChangeCallback(_callback!);
    await PhotoManager.startChangeNotify();
  }

  /// Manually trigger a rescan (used by Settings).
  /// If the indexer isn't running yet, it will start fast and then scan.
  Future<void> reindex({bool full = false}) async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      debugPrint('[MediaIndexer] reindex: Photos permission not granted.');
      return;
    }

    if (!_running) {
      debugPrint('[MediaIndexer] reindex: startFast() because not running');
      await startFast();
      return;
    }

    try {
      if (full) {
        debugPrint('[MediaIndexer] reindex: full scan');
        await _fullScan();
      } else {
        debugPrint('[MediaIndexer] reindex: incremental scan');
        await _incrementalScan();
      }
    } catch (e, st) {
      debugPrint('[MediaIndexer] reindex error: $e\n$st');
    }
  }

  Future<void> stop() async {
    _debounce?.cancel();
    if (_callback != null) {
      PhotoManager.removeChangeCallback(_callback!);
      _callback = null;
    }
    await PhotoManager.stopChangeNotify();
    _running = false;
  }

  // --- Scans ---

  Future<void> _seedScan() async {
    final isar = IsarService().db;
    final filter = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: filter,
    );
    if (albums.isEmpty) return;

    // Seed with first album’s first page only (fast)
    final album = albums.first;
    final assets = await album.getAssetListPaged(page: 0, size: 200);
    await _writeAssets(bucket: album.name, assets: assets, isar: isar);
    debugPrint('[MediaIndexer] seed: ${assets.length} items');
  }

  Future<void> _fullScan() async {
    final isar = IsarService().db;
    final filter = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: filter,
    );

    for (final album in albums) {
      int page = 0;
      const size = 200;
      while (true) {
        final assets = await album.getAssetListPaged(page: page, size: size);
        if (assets.isEmpty) break;
        page++;
        await _writeAssets(bucket: album.name, assets: assets, isar: isar);
        // yield to UI
        await Future.delayed(Duration.zero);
      }
    }
    await _markMissing(isar);
    debugPrint('[MediaIndexer] full scan done');
  }

  /// For now, incremental == full; the debounce keeps it cheap enough.
  Future<void> _incrementalScan() => _fullScan();

  // --- Helpers ---

Future<void> _writeAssets({
  required String bucket,
  required List<AssetEntity> assets,
  required Isar isar,
}) async {
  // One-time check for the whole album/bucket
  final bucketIsScreenshots = bucket.toLowerCase().contains('screenshot');

  await isar.writeTxn(() async {
    for (final a in assets) {
      final type = a.type == AssetType.video ? 'video' : 'image';
      final createdAt = a.createDateTime.millisecondsSinceEpoch;

      // Compute per-asset hints (now 'a' is in scope)
      final title = (a.title ?? '').toLowerCase();
      final looksLikeScreenshot = title.contains('screenshot');

      final existing = await isar.mediaEntrys.where().assetIdEqualTo(a.id).findFirst();
      if (existing == null) {
        final e = MediaEntry()
          ..assetId = a.id
          ..origin = 'system'
          ..type = type
          ..bucket = bucket
          ..createdAt = createdAt
          ..uri = ''
          ..tags = (bucketIsScreenshots || looksLikeScreenshot) ? ['screenshot'] : []
          ..favorite = false
          ..backedUp = false
          ..cloudKey = null
          ..trashed = false
          ..trashedAt = null
          ..missing = false;
        await isar.mediaEntrys.put(e);
      } else {
        // keep metadata fresh
        existing.bucket = bucket;
        existing.createdAt = createdAt;
        if (existing.missing) existing.missing = false;
        if (existing.trashed) {
          existing.trashed = false;
          existing.trashedAt = null;
        }
        // Add screenshot tag if appropriate and not already present
        if ((bucketIsScreenshots || looksLikeScreenshot) &&
            !existing.tags.contains('screenshot')) {
          existing.tags = [...existing.tags, 'screenshot'];
        }
        await isar.mediaEntrys.put(existing);
      }
    }
  });
}


  Future<void> _markMissing(Isar isar) async {
    final system = await isar.mediaEntrys
        .filter()
        .originEqualTo('system')
        .findAll();
    for (final e in system) {
      final alive = await AssetEntity.fromId(e.assetId!) != null;
      if (!alive && !e.missing) {
        await isar.writeTxn(() async {
          e.missing = true;
          await isar.mediaEntrys.put(e);
        });
      }
    }
  }
}
