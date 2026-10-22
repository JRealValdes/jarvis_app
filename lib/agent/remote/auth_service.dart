import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../config/app_config.dart';
import '../../data/secure_store.dart';
import 'endpoint.dart';
import 'remote_failure.dart';

/// Result of probing remote JWT validity (Auto-mode boot routing).
enum TokenValidationResult {
  valid,
  /// Missing JWT — need login when remote is the goal.
  noToken,
  /// Server returned 401/403 for a present token.
  invalidAuth,
  /// Missing URL / network / timeout — candidate for offline.
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
        _endpoint = endpoint ?? RemoteEndpoint(secureStore: secureStore),
        _http = httpClient ?? http.Client(),
        _timeout = transportTimeout ?? AppConfig.remoteTransportTimeout;

  final SecureStore _store;
  final RemoteEndpoint _endpoint;
  final http.Client _http;
  final Duration _timeout;

  Future<bool> login(String username, String password) async {
    List<String> bases;
    try {
      bases = await _endpoint.candidateBases();
    } on StateError {
      return false;
    }

    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    for (var i = 0; i < bases.length; i++) {
      final baseUrl = bases[i];
      final timeout =
          i == 0 ? _timeout : AppConfig.lanFallbackTimeout;
      try {
        final response = await _http
            .post(
              Uri.parse('$baseUrl/token'),
              headers: {
                'Authorization': basicAuth,
                'Content-Type': 'application/json',
              },
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          await _store.setJwtToken(data['access_token'] as String);
          return true;
        }
        // Reachable but bad credentials — do not try fallback.
        if (response.statusCode == 401 || response.statusCode == 403) {
          return false;
        }
      } on TimeoutException {
        continue;
      } on SocketException {
        continue;
      } on http.ClientException {
        continue;
      }
    }
    return false;
  }

  Future<String?> getToken() => _store.getJwtToken();

  Future<bool> validateToken() async {
    final result = await validateTokenDetailed();
    return result == TokenValidationResult.valid;
  }

  /// Classifies why validation failed (auth vs transport).
  Future<TokenValidationResult> validateTokenDetailed() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return TokenValidationResult.noToken;
    }

    List<String> bases;
    try {
      bases = await _endpoint.candidateBases();
    } on StateError {
      return TokenValidationResult.unreachable;
    }

    TokenValidationResult? lastTransport;
    for (var i = 0; i < bases.length; i++) {
      final baseUrl = bases[i];
      final timeout =
          i == 0 ? _timeout : AppConfig.lanFallbackTimeout;
      try {
        final response = await _http
            .get(
              Uri.parse('$baseUrl/validate-token'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          return TokenValidationResult.valid;
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          return TokenValidationResult.invalidAuth;
        }
        lastTransport = TokenValidationResult.unreachable;
      } on TimeoutException {
        lastTransport = TokenValidationResult.unreachable;
      } on SocketException {
        lastTransport = TokenValidationResult.unreachable;
      } on http.ClientException {
        lastTransport = TokenValidationResult.unreachable;
      } catch (e) {
        if (classifyRemoteFailure(e) == RemoteFailureKind.transport) {
          lastTransport = TokenValidationResult.unreachable;
        } else {
          return TokenValidationResult.unreachable;
        }
      }
    }
    return lastTransport ?? TokenValidationResult.unreachable;
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
