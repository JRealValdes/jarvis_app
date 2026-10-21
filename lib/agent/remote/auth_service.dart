import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../data/secure_store.dart';
import 'endpoint.dart';
import 'firebase_service.dart';

/// Remote FastAPI authentication (JWT). Not used in local mode.
class AuthService {
  AuthService({
    SecureStore? secureStore,
    RemoteEndpoint? endpoint,
  })  : _store = secureStore ?? SecureStore(),
        _endpoint = endpoint ?? RemoteEndpoint();

  final SecureStore _store;
  final RemoteEndpoint _endpoint;

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

    final response = await http.post(
      uri,
      headers: {
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await _store.setJwtToken(data['access_token'] as String);
      return true;
    }
    return false;
  }

  Future<String?> getToken() => _store.getJwtToken();

  Future<bool> validateToken() async {
    try {
      await FirebaseService.ensureInit();
    } catch (_) {
      return false;
    }
    final baseUrl = await _endpoint.resolve();
    if (baseUrl == null) return false;
    final token = await getToken();
    if (token == null) return false;

    final uri = Uri.parse('$baseUrl/validate-token');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    return response.statusCode == 200;
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
