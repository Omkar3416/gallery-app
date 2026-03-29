import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class FileHash {
  /// Streams the file to compute SHA1 hex (cheap+stable; good for dedupe).
  static Future<String> sha1OfFile(String path) async {
    Digest? digest;
    final sink = sha1.startChunkedConversion(
      ChunkedConversionSink.withCallback((digests) {
        digest = (digests as List<Digest>).first;
      }),
    );
    final file = File(path);
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return digest!.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
