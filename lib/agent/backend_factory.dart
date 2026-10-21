import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import 'jarvis_backend.dart';
import 'local_jarvis_agent.dart';
import 'remote_jarvis_api.dart';

/// Resolves the active [JarvisBackend] from the stored execution mode.
class BackendFactory {
  BackendFactory({SecureStore? secureStore})
      : _secureStore = secureStore ?? SecureStore();

  final SecureStore _secureStore;

  Future<JarvisMode> currentMode() => _secureStore.getMode();

  Future<JarvisBackend> create() async {
    final mode = await currentMode();
    switch (mode) {
      case JarvisMode.local:
        return LocalJarvisAgent(secureStore: _secureStore);
      case JarvisMode.remote:
        return RemoteJarvisApi();
    }
  }

  /// Admin Session Manager — only meaningful in remote mode.
  Future<RemoteJarvisApi> createRemote() async => RemoteJarvisApi();
}
