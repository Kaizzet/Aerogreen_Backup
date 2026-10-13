import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Simple wrapper that adds the base URL and optional JWT auth header.
class ApiClient {
  final String _baseUrl = dotenv.get('BACKEND_BASE_URL');

  String? _jwtToken;

  void setToken(String token) => _jwtToken = token;
  void clearToken() => _jwtToken = null;

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? jsonBody,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken!',
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(jsonBody ?? {}));
      case 'PUT':
        return http.put(uri, headers: headers, body: jsonEncode(jsonBody ?? {}));
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported HTTP method $method');
    }
  }

  // Public convenience helpers
  Future<http.Response> get(String path) => _request('GET', path);
  Future<http.Response> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, jsonBody: body);
  Future<http.Response> put(String path, {Map<String, dynamic>? body}) =>
      _request('PUT', path, jsonBody: body);
  Future<http.Response> delete(String path) => _request('DELETE', path);
}
