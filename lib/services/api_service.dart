import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'firebase_service.dart';

class ApiService {
  String? _baseUrl;
  final AuthService _auth = AuthService();
  final FirebaseService _fb = FirebaseService();

  Future<void> init() async {
    _baseUrl = await _fb.fetchApiBaseUrl();
  }

  Future<void> _ensureBaseUrl() async {
    if (_baseUrl == null) {
      await init();
    }
  }

  String get baseUrl => _baseUrl!;

  Future<http.Response> postAsk(Map<String, dynamic> body) async {
    await _ensureBaseUrl();
    final token = await _auth.getToken();
    final uri = Uri.parse('$_baseUrl/ask');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );
    if (response.statusCode == 404 || response.statusCode == 1016) {
      await init();
      return postAsk(body);
    }
    return response;
  }

  Future<http.Response> resetSession({String? threadId}) async {
    await _ensureBaseUrl();
    final uri = Uri.parse('$_baseUrl/reset-session');
    final body = threadId != null ? json.encode({'thread_id': threadId}) : null;
    final token = await _auth.getToken();

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 404 || response.statusCode == 1016) {
      await init();
      return resetSession(threadId: threadId);
    }
    return response;
  }

  Future<http.Response> resetGlobalMemory() async {
    await _ensureBaseUrl();
    return authorizedPost('$_baseUrl/admin/reset-global-memory');
  }

  Future<http.Response> getCacheStatus() async {
    await _ensureBaseUrl();
    return authorizedGet('$_baseUrl/admin/cache-status');
  }

  // === Authorized helpers ===
  Future<http.Response> authorizedGet(String url) async {
    final token = await _auth.getToken();
    final uri = Uri.parse(url);
    return http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }

  Future<http.Response> authorizedPost(String url, {Map<String, dynamic>? body}) async {
    final token = await _auth.getToken();
    final uri = Uri.parse(url);
    return http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body != null ? json.encode(body) : null,
    );
  }

    Future<http.Response> getMessageHistory({String? threadId}) async {
    await _ensureBaseUrl();
    final token = await _auth.getToken();
    final uri = threadId != null
        ? Uri.parse('$_baseUrl/message-history?thread_id=$threadId')
        : Uri.parse('$_baseUrl/message-history');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 404 || response.statusCode == 1016) {
      await init();
      return getMessageHistory(threadId: threadId);
    }

    return response;
  }
}
