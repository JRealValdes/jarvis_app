import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../domain/models/chat_turn.dart';
import '../jarvis_backend.dart';
import 'auth_service.dart';
import 'endpoint.dart';
import 'remote_cache_parsing.dart';
import 'remote_failure.dart';

/// Single remote FastAPI adapter: HTTP + decode (home/cloud server).
class RemoteJarvisApi implements JarvisBackend, JarvisAdminBackend {
  RemoteJarvisApi({
    AuthService? auth,
    RemoteEndpoint? endpoint,
    http.Client? httpClient,
    Duration? transportTimeout,
  })  : _auth = auth ?? AuthService(),
        _endpoint = endpoint ?? RemoteEndpoint(),
        _http = httpClient ?? http.Client(),
        _timeout = transportTimeout ?? AppConfig.remoteTransportTimeout;

  final AuthService _auth;
  final RemoteEndpoint _endpoint;
  final http.Client _http;
  final Duration _timeout;

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    return _withBases((base, timeout) async {
      final token = await _auth.getToken();
      final uri = Uri.parse('$base$path').replace(queryParameters: query);
      return _http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);
    }, label: 'GET $path');
  }

  Future<http.Response> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _withBases((base, timeout) async {
      final token = await _auth.getToken();
      return _http
          .post(
            Uri.parse('$base$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout);
    }, label: 'POST $path');
  }

  Future<http.Response> _withBases(
    Future<http.Response> Function(String base, Duration timeout) send, {
    required String label,
  }) async {
    final List<String> bases;
    try {
      bases = await _endpoint.candidateBases();
    } on StateError catch (e) {
      throw JarvisRemoteException(
        'Remote $label failed: $e',
        kind: RemoteFailureKind.transport,
      );
    }

    Object? lastError;
    for (var i = 0; i < bases.length; i++) {
      final timeout = i == 0 ? _timeout : AppConfig.lanFallbackTimeout;
      try {
        return await send(bases[i], timeout);
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on JarvisRemoteException {
        rethrow;
      } catch (e) {
        if (classifyRemoteFailure(e) == RemoteFailureKind.transport) {
          lastError = e;
          continue;
        }
        throw JarvisRemoteException(
          'Remote $label failed: $e',
          kind: classifyRemoteFailure(e),
        );
      }
    }
    throw JarvisRemoteException(
      'Remote $label failed: $lastError',
      kind: RemoteFailureKind.transport,
    );
  }

  void _ensureOk(http.Response resp, String label) {
    if (resp.statusCode == 200) return;
    throw JarvisRemoteException(
      '$label failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      kind: kindFromStatusCode(resp.statusCode),
    );
  }

  @override
  Future<List<String>> ask(String message, {required String modelName}) async {
    final resp = await _post('/ask', body: {
      'message': message,
      'model_name': modelName,
    });
    _ensureOk(resp, 'Ask');
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    return List<String>.from(decoded['response'] ?? []);
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) async {
    final resp = await _get(
      '/message-history',
      query: threadId != null ? {'thread_id': threadId} : null,
    );
    _ensureOk(resp, 'History');
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
    _ensureOk(resp, 'Reset');
  }

  @override
  Future<bool> individualCacheExists() async {
    final resp = await _get('/individual-cache-status');
    _ensureOk(resp, 'Cache exists check');
    final body = jsonDecode(resp.body);
    return body['exists'] == true;
  }

  @override
  Future<CacheStatus> getCacheStatus() async {
    final resp = await _get('/admin/cache-status');
    _ensureOk(resp, 'Cache status');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final models = List<String>.from(data['agent_models'] ?? []);
    final sessions =
        parseCacheSessionList(data['sessions'] as List<dynamic>? ?? []);
    return CacheStatus(agentModels: models, sessions: sessions);
  }

  @override
  Future<void> resetGlobalMemory() async {
    final resp = await _post('/admin/reset-global-memory');
    _ensureOk(resp, 'Global reset');
  }
}
