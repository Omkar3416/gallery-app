import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileIO {
  /// Copies [file] into app's documents directory if it's not already there.
  static Future<File> ensureInAppDir(File file) async {
    final docs = await getApplicationDocumentsDirectory();
    final destPath = p.join(docs.path, 'media', p.basename(file.path));
    final destFile = File(destPath);
    if (await destFile.exists()) return destFile;

    await destFile.parent.create(recursive: true);
    return file.copy(destPath);
  }

  static Future<int> createdAtMillis(File file) async {
    try {
      final stat = await file.stat();
      return stat.changed.millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}
