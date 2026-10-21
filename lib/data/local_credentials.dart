import '../domain/models/user_profile.dart';
import 'secure_store.dart';

/// On-device OpenAI credentials and profile (failover / local-only).
class LocalCredentials {
  LocalCredentials({SecureStore? store}) : _store = store ?? SecureStore();

  final SecureStore _store;

  Future<String?> getOpenAiApiKey() => _store.getOpenAiApiKey();

  Future<void> setOpenAiApiKey(String key) => _store.setOpenAiApiKey(key);

  Future<void> clearOpenAiApiKey() => _store.clearOpenAiApiKey();

  Future<String> getOpenAiModel() => _store.getOpenAiModel();

  Future<void> setOpenAiModel(String model) => _store.setOpenAiModel(model);

  Future<UserProfile?> getUserProfile() => _store.getUserProfile();

  Future<void> setUserProfile(UserProfile profile) =>
      _store.setUserProfile(profile);

  Future<bool> isConfigured() => _store.isLocalConfigured();

  Future<bool> hasApiKey() async {
    final key = await getOpenAiApiKey();
    return key != null && key.trim().isNotEmpty;
  }
}
