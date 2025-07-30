import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _storage = FlutterSecureStorage();
  final _baseUrl = '<TU_BACKEND_URL>'; // e.g. from Firebase/firebase_service

  Future<bool> login(String username, String password) async {
    final uri = Uri.parse('$_baseUrl/token');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=$username&password=$password',
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'jwt_token', value: data['access_token']);
      return true;
    }
    return false;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }
}
