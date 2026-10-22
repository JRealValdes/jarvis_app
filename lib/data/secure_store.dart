import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../domain/models/jarvis_mode.dart';
import '../domain/models/user_profile.dart';

/// Secure persistence for secrets and local preferences (Keystore on Android).
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyMode = 'jarvis_mode';
  static const _keyOpenAiApiKey = 'openai_api_key';
  static const _keyOpenAiModel = 'openai_model';
  static const _keyProfile = 'user_profile';
  static const _keyJwt = 'jwt_token';
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';
  static const _keyApiBaseUrl = 'api_base_url';

  Future<JarvisMode> getMode() async {
    final value = await _storage.read(key: _keyMode);
    if (value == null) return JarvisMode.fromStorage(AppConfig.defaultMode);
    return JarvisMode.fromStorage(value);
  }

  Future<void> setMode(JarvisMode mode) async {
    await _storage.write(key: _keyMode, value: mode.storageValue);
  }

  Future<String?> getOpenAiApiKey() => _storage.read(key: _keyOpenAiApiKey);

  Future<void> setOpenAiApiKey(String key) async {
    await _storage.write(key: _keyOpenAiApiKey, value: key.trim());
  }

  Future<void> clearOpenAiApiKey() async {
    await _storage.delete(key: _keyOpenAiApiKey);
  }

  Future<String> getOpenAiModel() async {
    return await _storage.read(key: _keyOpenAiModel) ??
        AppConfig.defaultOpenAiModel;
  }

  Future<void> setOpenAiModel(String model) async {
    await _storage.write(key: _keyOpenAiModel, value: model);
  }

  Future<UserProfile?> getUserProfile() async {
    final raw = await _storage.read(key: _keyProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setUserProfile(UserProfile profile) async {
    await _storage.write(key: _keyProfile, value: jsonEncode(profile.toJson()));
  }

  /// Local mode is ready when an API key and a non-empty Jarvis name are set.
  Future<bool> isLocalConfigured() async {
    final key = await getOpenAiApiKey();
    final profile = await getUserProfile();
    return key != null &&
        key.trim().isNotEmpty &&
        profile != null &&
        profile.jarvisName.trim().isNotEmpty;
  }

  Future<String?> getJwtToken() => _storage.read(key: _keyJwt);

  Future<void> setJwtToken(String token) async {
    await _storage.write(key: _keyJwt, value: token);
  }

  Future<void> deleteJwtToken() async {
    await _storage.delete(key: _keyJwt);
  }

  Future<String?> getUsername() => _storage.read(key: _keyUsername);

  Future<void> setUsername(String username) async {
    await _storage.write(key: _keyUsername, value: username);
  }

  Future<void> deleteUsername() async {
    await _storage.delete(key: _keyUsername);
  }

  Future<String?> getPassword() => _storage.read(key: _keyPassword);

  Future<void> setPassword(String password) async {
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<void> deletePassword() async {
    await _storage.delete(key: _keyPassword);
  }

  Future<void> clearRemoteCredentials() async {
    await deleteJwtToken();
    await deleteUsername();
    await deletePassword();
  }

  /// Operator-configured Jarvis FastAPI base URL (LAN / Tailscale later).
  Future<String?> getApiBaseUrl() => _storage.read(key: _keyApiBaseUrl);

  Future<void> setApiBaseUrl(String url) async {
    await _storage.write(key: _keyApiBaseUrl, value: url.trim());
  }

  Future<void> clearApiBaseUrl() async {
    await _storage.delete(key: _keyApiBaseUrl);
  }
}
