import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class MultipartUploadFile {
  final Uint8List bytes;
  final String filename;

  const MultipartUploadFile({required this.bytes, required this.filename});
}

class ApiClient {
  String? token;
  VoidCallback? onUnauthorized;

  Map<String, String> get authenticatedHeaders => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${AppConfig.apiBase}$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_u(path, query), headers: _headers));

  Future<Uint8List> getBytes(String path) async {
    final response = await _raw(
      () => http.get(_u(path), headers: authenticatedHeaders),
    );
    return response.bodyBytes;
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(() =>
      http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send(
      () => http.put(_u(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<MultipartUploadFile> files,
  }) {
    final request = http.MultipartRequest('POST', _u(path))
      ..headers.addAll(authenticatedHeaders)
      ..fields.addAll(fields);
    request.files.addAll([
      for (var i = 0; i < files.length; i++)
        http.MultipartFile.fromBytes(
          '$fileField[$i]',
          files[i].bytes,
          filename: files[i].filename,
        ),
    ]);

    return _send(() async {
      final response = await request.send();
      return http.Response.fromStream(response);
    });
  }

  /// For the CSV export
  Future<String> getText(String path, {Map<String, String>? query}) async {
    final res = await _raw(() => http.get(_u(path, query), headers: _headers));
    return res.body;
  }

  Future<http.Response> _raw(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Is the Laravel API running?');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return res;

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {}

    if (res.statusCode == 401 && token != null) onUnauthorized?.call();

    var msg = 'Request failed (${res.statusCode})';
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        msg = first is List && first.isNotEmpty
            ? first.first.toString()
            : first.toString();
      } else if (data['message'] != null) {
        msg = data['message'].toString();
      }
    }
    throw ApiException(msg, res.statusCode);
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final res = await _raw(call);
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }
}
