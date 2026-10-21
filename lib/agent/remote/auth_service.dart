import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../config/app_config.dart';
import '../../data/secure_store.dart';
import 'endpoint.dart';
import 'firebase_service.dart';
import 'remote_failure.dart';

/// Result of probing remote JWT validity (Auto-mode boot routing).
enum TokenValidationResult {
  valid,
  /// Missing JWT — need login when remote is the goal.
  noToken,
  /// Server returned 401/403 for a present token.
  invalidAuth,
  /// Firebase / URL / network / timeout — candidate for offline.
  unreachable,
}

/// Remote FastAPI authentication (JWT). Not used in local-only mode.
class AuthService {
  AuthService({
    SecureStore? secureStore,
    RemoteEndpoint? endpoint,
    http.Client? httpClient,
    Duration? transportTimeout,
  })  : _store = secureStore ?? SecureStore(),
        _endpoint = endpoint ?? RemoteEndpoint(),
        _http = httpClient ?? http.Client(),
        _timeout = transportTimeout ?? AppConfig.remoteTransportTimeout;

  final SecureStore _store;
  final RemoteEndpoint _endpoint;
  final http.Client _http;
  final Duration _timeout;

  Future<bool> login(String username, String password) async {
    try {
      await FirebaseService.ensureInit();
    } catch (_) {
      return false;
    }
    final baseUrl = await _endpoint.resolve(forceRefresh: true);
    if (baseUrl == null) return false;

    final uri = Uri.parse('$baseUrl/token');
    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    try {
      final response = await _http
          .post(
            uri,
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await _store.setJwtToken(data['access_token'] as String);
        return true;
      }
      return false;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  Future<String?> getToken() => _store.getJwtToken();

  Future<bool> validateToken() async {
    final result = await validateTokenDetailed();
    return result == TokenValidationResult.valid;
  }

  /// Classifies why validation failed (auth vs transport).
  Future<TokenValidationResult> validateTokenDetailed() async {
    try {
      await FirebaseService.ensureInit();
    } catch (_) {
      return TokenValidationResult.unreachable;
    }

    final token = await getToken();
    if (token == null || token.isEmpty) {
      return TokenValidationResult.noToken;
    }

    String? baseUrl;
    try {
      baseUrl = await _endpoint.resolve();
    } catch (_) {
      return TokenValidationResult.unreachable;
    }
    if (baseUrl == null || baseUrl.isEmpty) {
      return TokenValidationResult.unreachable;
    }

    try {
      final uri = Uri.parse('$baseUrl/validate-token');
      final response = await _http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return TokenValidationResult.valid;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return TokenValidationResult.invalidAuth;
      }
      if (RemoteEndpoint.isStaleTunnelStatus(response.statusCode)) {
        return TokenValidationResult.unreachable;
      }
      // Reachable but unexpected — treat as auth-ish only for 401 path above.
      return TokenValidationResult.unreachable;
    } on TimeoutException {
      return TokenValidationResult.unreachable;
    } on SocketException {
      return TokenValidationResult.unreachable;
    } on http.ClientException {
      return TokenValidationResult.unreachable;
    } catch (e) {
      if (classifyRemoteFailure(e) == RemoteFailureKind.transport) {
        return TokenValidationResult.unreachable;
      }
      return TokenValidationResult.unreachable;
    }
  }

  Future<Map<String, dynamic>?> getTokenData() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      return JwtDecoder.decode(token);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _store.clearRemoteCredentials();
  }

  Future<bool> isAdmin() async {
    final tokenData = await getTokenData();
    return isAdminClaim(tokenData?['admin']);
  }

  /// JWT `admin` may be a Python bool (`true`) or a legacy `1`.
  static bool isAdminClaim(Object? value) {
    if (value == true || value == 1) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }
}
