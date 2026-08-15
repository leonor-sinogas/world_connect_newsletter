import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_URL',
            defaultValue: 'http://localhost:8000',
          );

  final String baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final response = await http.Request(method, Uri.parse('$baseUrl$path'))
        .also((request) {
          request.headers['Accept'] = 'application/json';
          request.headers['Content-Type'] = 'application/json';
          if (_token != null) {
            request.headers['Authorization'] = 'Bearer $_token';
          }
          if (body != null) request.body = jsonEncode(body);
        })
        .send()
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 15));
    final dynamic decoded = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded is Map
            ? decoded['detail']?.toString() ?? 'Request failed'
            : 'Request failed',
        response.statusCode,
      );
    }
    return decoded;
  }

  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final mediaType = _imageMediaType(bytes, filename);
    if (mediaType == null) {
      throw const ApiException('Only JPG and PNG images are supported.', 400);
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw const ApiException('Images must be smaller than 5 MB.', 400);
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/uploads'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: _safeImageFilename(filename, mediaType.subtype),
        contentType: mediaType,
      ),
    );
    final response = await http.Response.fromStream(
      await request.send(),
    ).timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['detail']?.toString() ?? 'Upload failed',
        response.statusCode,
      );
    }
    return decoded['url'] as String;
  }

  MediaType? _imageMediaType(Uint8List bytes, String filename) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return MediaType('image', 'jpeg');
    }
    // Give callers a useful error for empty/corrupt files even when their name
    // has a familiar suffix. The server independently verifies the signature.
    final extension = filename.toLowerCase().split('.').last;
    if (extension == 'png' || extension == 'jpg' || extension == 'jpeg') {
      return null;
    }
    return null;
  }

  String _safeImageFilename(String filename, String subtype) {
    final base = filename
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'\.(png|jpe?g)$', caseSensitive: false), '');
    return '${base.isEmpty ? 'image' : base}.${subtype == 'jpeg' ? 'jpg' : 'png'}';
  }
}

extension<T> on T {
  T also(void Function(T value) action) {
    action(this);
    return this;
  }
}
