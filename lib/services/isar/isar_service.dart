// lib/services/isar/isar_service.dart
import 'dart:async';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'schemas/media_entry.dart';

/// Central Isar access used across Gallery/Albums/Backup/Viewer.
/// This version matches your schema usage in UI:
/// - createdAt: int (ms since epoch)
/// - trashed: bool
/// - trashedAt: int? (ms since epoch)
/// - favorite: bool
/// - type: 'image' | 'video'
/// - bucket: String
/// - assetId: String?
/// - uri: String
/// - backedUp: bool
/// - cloudKey: String?
class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  Isar? _isar;

  Isar get db {
    final isar = _isar;
    if (isar == null) {
      throw StateError('Isar is not initialized. Call IsarService().init() first.');
    }
    return isar;
  }

  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [MediaEntrySchema],
      directory: dir.path,
      inspector: false,
    );
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }

  Future<Directory> get appDir async => await getApplicationDocumentsDirectory();

  // -------------------- CRUD convenience --------------------

  Future<Id> addMedia(MediaEntry entry) async {
    return db.writeTxn(() => db.mediaEntrys.put(entry));
  }

  /// One-shot list (not filtered)
  Future<List<MediaEntry>> getAll() async {
    final l = await db.mediaEntrys.where().findAll();
    l.sort((a, b) => (b.createdAt).compareTo(a.createdAt));
    return l;
  }

  // -------------------- Streams used in UI --------------------

  /// All (NOT trashed), newest first
  Stream<List<MediaEntry>> watchAllNotTrashed() {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l.where((e) => !e.trashed).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Photos only (NOT trashed)
  Stream<List<MediaEntry>> watchPhotos() {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l.where((e) => !e.trashed && e.type == 'image').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Videos only (NOT trashed)
  Stream<List<MediaEntry>> watchVideos() {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l.where((e) => !e.trashed && e.type == 'video').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Favourites (NOT trashed)
  Stream<List<MediaEntry>> watchFavorites() {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l.where((e) => !e.trashed && e.favorite).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Bucket name contains [keyword] (NOT trashed)
  Stream<List<MediaEntry>> watchBucketContains(String keyword) {
    final k = keyword.toLowerCase();
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l
          .where((e) => !e.trashed && (e.bucket.toLowerCase().contains(k)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Items created within last [days] (NOT trashed)
  Stream<List<MediaEntry>> watchRecentDays(int days) {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l.where((e) => !e.trashed && e.createdAt >= since).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Trashed only, newest first (by trashedAt then createdAt)
  Stream<List<MediaEntry>> watchTrashed() {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l.where((e) => e.trashed).toList()
        ..sort((a, b) {
          final bt = b.trashedAt ?? b.createdAt;
          final at = a.trashedAt ?? a.createdAt;
          return bt.compareTo(at);
        });
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  /// Not trashed & not yet backed up (either backedUp==false or cloudKey empty)
  Stream<List<MediaEntry>> watchUnbacked() {
    final c = StreamController<List<MediaEntry>>();
    Future<void> emit() async {
      final l = await db.mediaEntrys.where().findAll();
      final filtered = l
          .where((e) =>
              !e.trashed &&
              (!e.backedUp || (e.cloudKey == null || e.cloudKey!.isEmpty)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      c.add(filtered);
    }

    emit();
    final sub = db.mediaEntrys.watchLazy(fireImmediately: false).listen((_) => emit());
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  // -------------------- Mutations --------------------

  Future<void> toggleFavorite(Id id, bool value) async {
    await db.writeTxn(() async {
      final item = await db.mediaEntrys.get(id);
      if (item != null) {
        item.favorite = value;
        await db.mediaEntrys.put(item);
      }
    });
  }

  Future<void> setBackedUp(
    int id, {
    required bool value,
    String? cloudKey,
  }) async {
    await db.writeTxn(() async {
      final item = await db.mediaEntrys.get(id);
      if (item != null) {
        item.backedUp = value;
        if (cloudKey != null) item.cloudKey = cloudKey;
        await db.mediaEntrys.put(item);
      }
    });
  }

  Future<void> moveToTrash(int id) async {
    await db.writeTxn(() async {
      final e = await db.mediaEntrys.get(id);
      if (e != null && !e.trashed) {
        e.trashed = true;
        e.trashedAt = DateTime.now().millisecondsSinceEpoch;
        await db.mediaEntrys.put(e);
      }
    });
  }

  Future<void> restoreFromTrash(int id) async {
    await db.writeTxn(() async {
      final e = await db.mediaEntrys.get(id);
      if (e != null && e.trashed) {
        e.trashed = false;
        e.trashedAt = null;
        await db.mediaEntrys.put(e);
      }
    });
  }

  Future<void> deletePermanently({
    int? id,
    String? assetId,
    String? uri,
  }) async {
    await db.writeTxn(() async {
      if (id != null) {
        await db.mediaEntrys.delete(id);
      }
      if (assetId != null) {
        final e = await db.mediaEntrys.where().assetIdEqualTo(assetId).findFirst();
        if (e != null) await db.mediaEntrys.delete(e.id);
      }
      if (uri != null) {
        final all = await db.mediaEntrys.filter().uriEqualTo(uri).findAll();
        for (final e in all) {
          await db.mediaEntrys.delete(e.id);
        }
      }
    });
  }

  /// Update file path and bucket (used by Viewer → Rename)
  Future<void> updatePath({required int id, required String newPath}) async {
    await db.writeTxn(() async {
      final entry = await db.mediaEntrys.get(id);
      if (entry == null) return;
      entry.uri = newPath;
      // refresh bucket from parent folder name
      try {
        entry.bucket = p.basename(p.dirname(newPath));
      } catch (_) {
        // keep old bucket if parsing fails
      }
      await db.mediaEntrys.put(entry);
    });
  }

  /// Permanently removes trashed items older than [days].
  Future<int> purgeTrashedOlderThanDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final all = await db.mediaEntrys.where().findAll();
    final toDelete = all.where((e) {
      final when = e.trashedAt ?? e.createdAt;
      return e.trashed && when < cutoff;
    }).toList();

    await db.writeTxn(() async {
      for (final e in toDelete) {
        await db.mediaEntrys.delete(e.id);
      }
    });
    return toDelete.length;
  }

  /// Merge/replace tags safely
  Future<void> setTags(int id, List<String> tags, {bool replace = false}) async {
    await db.writeTxn(() async {
      final e = await db.mediaEntrys.get(id);
      if (e == null) return;
      if (replace) {
        e.tags = tags;
      } else {
        final s = {...e.tags, ...tags};
        e.tags = s.toList()..sort();
      }
      await db.mediaEntrys.put(e);
    });
  }
}
