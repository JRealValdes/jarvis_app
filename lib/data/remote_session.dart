import 'secure_store.dart';

/// Remote FastAPI session secrets (JWT + optional login autofill).
class RemoteSession {
  RemoteSession({SecureStore? store}) : _store = store ?? SecureStore();

  final SecureStore _store;

  Future<String?> getJwtToken() => _store.getJwtToken();

  Future<void> setJwtToken(String token) => _store.setJwtToken(token);

  Future<void> deleteJwtToken() => _store.deleteJwtToken();

  Future<String?> getUsername() => _store.getUsername();

  Future<void> setUsername(String username) => _store.setUsername(username);

  Future<void> deleteUsername() => _store.deleteUsername();

  Future<String?> getPassword() => _store.getPassword();

  Future<void> setPassword(String password) => _store.setPassword(password);

  Future<void> deletePassword() => _store.deletePassword();

  Future<void> clear() => _store.clearRemoteCredentials();
}
