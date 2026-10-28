import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../config/app_config.dart';
import '../../domain/chat_image.dart';
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
    Duration? askTimeout,
  })  : _auth = auth ?? AuthService(),
        _endpoint = endpoint ?? RemoteEndpoint(),
        _http = httpClient ?? http.Client(),
        _timeout = transportTimeout ?? AppConfig.remoteTransportTimeout,
        _askTimeout = askTimeout ?? AppConfig.remoteAskTimeout;

  final AuthService _auth;
  final RemoteEndpoint _endpoint;
  final http.Client _http;
  final Duration _timeout;
  final Duration _askTimeout;

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
    Duration? timeoutOverride,
  }) async {
    return _withBases(
      (base, timeout) async {
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
      },
      label: 'POST $path',
      primaryTimeout: timeoutOverride,
    );
  }

  Future<http.Response> _withBases(
    Future<http.Response> Function(String base, Duration timeout) send, {
    required String label,
    Duration? primaryTimeout,
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

    final primary = primaryTimeout ?? _timeout;
    Object? lastError;
    for (var i = 0; i < bases.length; i++) {
      final timeout = i == 0 ? primary : AppConfig.lanFallbackTimeout;
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

  Future<http.Response> _sendMultipart({
    required String base,
    required String path,
    required String fieldName,
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw JarvisRemoteException(
        'Remote transcription requires a login.',
        statusCode: 401,
        kind: RemoteFailureKind.auth,
      );
    }
    final request = http.MultipartRequest('POST', Uri.parse('$base$path'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        // Extension is required; octet-stream is an accepted part type.
        contentType: MediaType('application', 'octet-stream'),
      ),
    );
    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _postMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    Duration? timeoutOverride,
  }) async {
    return _withBases(
      (base, timeout) {
        return _sendMultipart(
          base: base,
          path: path,
          fieldName: fieldName,
          bytes: bytes,
          filename: filename,
        ).timeout(timeout);
      },
      label: 'POST $path',
      primaryTimeout: timeoutOverride,
    );
  }

  /// `POST /transcribe`: multipart field `file`, Bearer JWT, body `{text}`.
  ///
  /// The server does not keep the audio. Local / offline dictation must not
  /// call this method.
  Future<String> transcribeAudio({
    required List<int> bytes,
    required String filename,
  }) async {
    final resp = await _postMultipart(
      '/transcribe',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      timeoutOverride: AppConfig.remoteTranscribeTimeout,
    );
    if (resp.statusCode != 200) {
      final detail = readFastApiDetail(resp);
      throw JarvisRemoteException(
        detail ?? 'Transcription failed: ${resp.statusCode}',
        statusCode: resp.statusCode,
        kind: kindFromStatusCode(resp.statusCode),
      );
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! Map || decoded['text'] is! String) {
      throw JarvisRemoteException(
        'Transcription response missing text',
        statusCode: resp.statusCode,
        kind: RemoteFailureKind.other,
      );
    }
    return decoded['text'] as String;
  }

  void _ensureOk(http.Response resp, String label) {
    if (resp.statusCode == 200) return;
    throw JarvisRemoteException(
      '$label failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      kind: kindFromStatusCode(resp.statusCode),
    );
  }

  /// `POST /ask`. Images ride on the same JSON body (`media_type` + base64).
  ///
  /// Omit [images] for a text turn so the body stays `{message, model_name}`.
  /// A blank [message] is valid when [images] is non-empty. Audio bytes never
  /// go here — transcribe them first and put the text in [message].
  @override
  Future<List<String>> ask(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'model_name': modelName,
    };
    if (images.isNotEmpty) {
      body['images'] = [for (final image in images) image.toAskJson()];
    }
    final resp = await _post(
      '/ask',
      body: body,
      timeoutOverride: _askTimeout,
    );
    if (resp.statusCode != 200) {
      final detail = readFastApiDetail(resp);
      throw JarvisRemoteException(
        detail ?? 'Ask failed: ${resp.statusCode}',
        statusCode: resp.statusCode,
        kind: kindFromStatusCode(resp.statusCode),
      );
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

/// FastAPI `detail` when it is a string. Validation-error lists are ignored.
String? readFastApiDetail(http.Response resp) {
  try {
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is Map) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
    }
  } catch (_) {}
  return null;
}
