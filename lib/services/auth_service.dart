import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'firebase_service.dart'; // <-- importa esto

class AuthService {
  final _storage = FlutterSecureStorage();
  final FirebaseService _firebase = FirebaseService();

  Future<bool> login(String username, String password) async {
    final baseUrl = await _firebase.fetchApiBaseUrl();
    print('🔍 baseUrl recuperado: $baseUrl');

    if (baseUrl == null) {
      print('❌ baseUrl es null');
      return false;
    }

    print('🔑 Intentando iniciar sesión con usuario: $username');
    print('🔐 Intentando iniciar sesión con contraseña: $password');
    final uri = Uri.parse('$baseUrl/token');
    final basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));
    print('🌐 URI final: $uri');
    print('🔑 Auth header: $basicAuth');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': basicAuth,
        'Content-Type': 'application/json'
      }
    );

    print('📡 Código de respuesta: ${response.statusCode}');
    print('📨 Respuesta body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('🔐 Token recibido: ${data['access_token']}');
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
