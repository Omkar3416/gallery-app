// lib/services/aws/storage/aws_storage.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../core/config/app_settings.dart';

class AwsStorage {
  Future<String> uploadFile({
    required File file,
    String? preferredKey,
    Map<String, String>? extraTags,
  }) async {
    final settings = AppSettings();
    final baseUrl = settings.lambdaUrl.trim();
    if (baseUrl.isEmpty) {
      throw 'Lambda base URL is empty. Set it in Settings → Developer → Lambda base URL.';
    }
    final uri = Uri.parse(baseUrl);

    final key = preferredKey ?? _defaultKeyFor(file.path);
    final contentType = _guessContentType(p.extension(file.path).toLowerCase());

    final headers = <String, String>{
      'content-type': 'application/json',
      if (settings.appKey.isNotEmpty) 'x-app-key': settings.appKey,
    };

    final reqBody = jsonEncode({
      'key': key,
      'contentType': contentType,
    });

    final presignRes = await http.post(uri, headers: headers, body: reqBody);
    if (presignRes.statusCode != 200) {
      throw 'Presign failed (${presignRes.statusCode}): ${presignRes.body}';
    }

    final resp = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final putUrl = (resp['putUrl'] ?? resp['url']) as String?;
    final returnedKey = (resp['key'] as String?) ?? key;
    if (putUrl == null || putUrl.isEmpty) {
      throw 'Presign response missing putUrl/url';
    }

    final bytes = await file.readAsBytes();
    final putRes = await http.put(
      Uri.parse(putUrl),
      headers: {
        'content-type': contentType,
        'content-length': '${bytes.length}',
      },
      body: bytes,
    );
    if (putRes.statusCode != 200 && putRes.statusCode != 201) {
      throw 'S3 upload failed (${putRes.statusCode})';
    }
    return returnedKey;
  }

  /// Same as [uploadFile] but lets the caller pass a [client] that can be closed to cancel.
  Future<String> uploadFileWithClient({
    required File file,
    http.Client? client,
    String? preferredKey,
  }) async {
    final settings = AppSettings();
    final baseUrl = settings.lambdaUrl.trim();
    if (baseUrl.isEmpty) {
      throw 'Lambda base URL is empty. Set it in Settings → Developer → Lambda base URL.';
    }
    final key = preferredKey ?? _defaultKeyFor(file.path);
    final contentType = _guessContentType(p.extension(file.path).toLowerCase());

    final _client = client ?? http.Client();
    bool shouldClose = client == null;

    try {
      // 1) presign
      final presignRes = await _client.post(
        Uri.parse(baseUrl),
        headers: {
          'content-type': 'application/json',
          if (settings.appKey.isNotEmpty) 'x-app-key': settings.appKey,
        },
        body: jsonEncode({'key': key, 'contentType': contentType}),
      );
      if (presignRes.statusCode != 200) {
        throw 'Presign failed (${presignRes.statusCode}): ${presignRes.body}';
      }
      final resp = jsonDecode(presignRes.body) as Map<String, dynamic>;
      final putUrl = (resp['putUrl'] ?? resp['url']) as String?;
      final returnedKey = (resp['key'] as String?) ?? key;
      if (putUrl == null || putUrl.isEmpty) {
        throw 'Presign response missing putUrl/url';
      }

      // 2) stream PUT; closing the client cancels the request
      final bytes = await file.readAsBytes();
      final req = http.Request('PUT', Uri.parse(putUrl))
        ..headers['content-type'] = contentType
        ..headers['content-length'] = '${bytes.length}'
        ..bodyBytes = bytes;

      final streamed = await _client.send(req);
      final code = streamed.statusCode;
      // drain the stream to complete
      await streamed.stream.fold<List<int>>([], (a, b) => a..addAll(b));

      if (code != 200 && code != 201) {
        throw 'S3 upload failed ($code)';
      }
      return returnedKey;
    } finally {
      if (shouldClose) _client.close();
    }
  }
  /// Ask Lambda to presign a **GET** URL so the app can preview a private S3 object.
  Future<String> getDownloadUrl({
    required String key,
    Duration expires = const Duration(minutes: 10),
  }) async {
    final settings = AppSettings();
    final baseUrl = settings.lambdaUrl.trim();
    if (baseUrl.isEmpty) {
      throw 'Lambda base URL is empty. Set it in Settings → Developer → Lambda base URL.';
    }

    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'content-type': 'application/json',
        if (settings.appKey.isNotEmpty) 'x-app-key': settings.appKey,
      },
      body: jsonEncode({
        'key': key,
        'method': 'GET',
        'expiresIn': expires.inSeconds,
      }),
    );

    if (res.statusCode != 200) {
      throw 'Presign-GET failed (${res.statusCode}): ${res.body}';
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final url = (json['getUrl'] ?? json['url'] ?? json['signedUrl']) as String?;
    if (url == null || url.isEmpty) {
      throw 'Lambda response missing getUrl/url';
    }
    return url;
  }



  String _defaultKeyFor(String path) {
    final name = path.split('/').last;
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
    return 'uploads/$ts-$name';
  }

  String _guessContentType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream';
    }
  }
}
