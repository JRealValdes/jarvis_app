import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import 'failover_jarvis_backend.dart';
import 'jarvis_backend.dart';
import 'local_jarvis_agent.dart';
import 'remote/remote_jarvis_api.dart';

/// Resolves the active [JarvisBackend] from the stored execution mode.
class BackendFactory {
  BackendFactory({
    SecureStore? secureStore,
    void Function()? onEnteredOffline,
  })  : _secureStore = secureStore ?? SecureStore(),
        _onEnteredOffline = onEnteredOffline;

  final SecureStore _secureStore;
  final void Function()? _onEnteredOffline;

  Future<JarvisMode> currentMode() => _secureStore.getMode();

  Future<JarvisBackend> create() async {
    final mode = await currentMode();
    switch (mode) {
      case JarvisMode.local:
        return LocalJarvisAgent(secureStore: _secureStore);
      case JarvisMode.remote:
        return RemoteJarvisApi();
      case JarvisMode.auto:
        return FailoverJarvisBackend(
          secureStore: _secureStore,
          onEnteredOffline: _onEnteredOffline,
        );
    }
  }

  /// Admin Session Manager — remote FastAPI only.
  Future<RemoteJarvisApi> createRemote() async => RemoteJarvisApi();
}
