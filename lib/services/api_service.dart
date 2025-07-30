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
    if (response.statusCode == 404) {
      await init(); // reload baseUrl
      return postAsk(body); // retry
    }
    return response;
  }

  Future<void> _ensureBaseUrl() async {
    if (_baseUrl == null) {
      await init();
    }
  }
}
