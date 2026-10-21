import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/chat_turn.dart';
import '../jarvis_backend.dart';
import 'auth_service.dart';
import 'endpoint.dart';
import 'remote_cache_parsing.dart';

/// Single remote FastAPI adapter: HTTP + decode (home/cloud server).
class RemoteJarvisApi implements JarvisBackend, JarvisAdminBackend {
  RemoteJarvisApi({
    AuthService? auth,
    RemoteEndpoint? endpoint,
  })  : _auth = auth ?? AuthService(),
        _endpoint = endpoint ?? RemoteEndpoint();

  final AuthService _auth;
  final RemoteEndpoint _endpoint;

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final base = await _endpoint.requireBaseUrl();
    final token = await _auth.getToken();
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    if (RemoteEndpoint.isStaleTunnelStatus(response.statusCode)) {
      await _endpoint.requireBaseUrl(forceRefresh: true);
      return _get(path, query: query);
    }
    return response;
  }

  Future<http.Response> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final base = await _endpoint.requireBaseUrl();
    final token = await _auth.getToken();
    final response = await http.post(
      Uri.parse('$base$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: body != null ? json.encode(body) : null,
    );
    if (RemoteEndpoint.isStaleTunnelStatus(response.statusCode)) {
      await _endpoint.requireBaseUrl(forceRefresh: true);
      return _post(path, body: body);
    }
    return response;
  }

  @override
  Future<List<String>> ask(String message, {required String modelName}) async {
    final resp = await _post('/ask', body: {
      'message': message,
      'model_name': modelName,
    });
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Ask failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    return List<String>.from(decoded['response'] ?? []);
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) async {
    final resp = await _get(
      '/message-history',
      query: threadId != null ? {'thread_id': threadId} : null,
    );
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('History failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final history = decoded['messages'] as List<dynamic>? ?? [];
    return history
        .map((m) => ChatTurn.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  @override
  Future<void> resetSession({String? threadId}) async {
    final resp = await _post(
      '/reset-session',
      body: threadId != null ? {'thread_id': threadId} : null,
    );
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Reset failed: ${resp.statusCode}');
    }
  }

  @override
  Future<bool> individualCacheExists() async {
    final resp = await _get('/individual-cache-status');
    if (resp.statusCode != 200) {
      throw JarvisRemoteException(
        'Cache exists check failed: ${resp.statusCode}',
      );
    }
    final body = jsonDecode(resp.body);
    return body['exists'] == true;
  }

  @override
  Future<CacheStatus> getCacheStatus() async {
    final resp = await _get('/admin/cache-status');
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Cache status failed: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final models = List<String>.from(data['agent_models'] ?? []);
    final sessions =
        parseCacheSessionList(data['sessions'] as List<dynamic>? ?? []);
    return CacheStatus(agentModels: models, sessions: sessions);
  }

  @override
  Future<void> resetGlobalMemory() async {
    final resp = await _post('/admin/reset-global-memory');
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Global reset failed: ${resp.statusCode}');
    }
  }
}

class JarvisRemoteException implements Exception {
  JarvisRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}
