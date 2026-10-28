import '../data/local_credentials.dart';
import '../data/memory_message_store.dart';
import '../data/secure_store.dart';
import '../domain/chat_image.dart';
import '../domain/chat_state.dart';
import '../domain/models/chat_turn.dart';
import 'jarvis_backend.dart';
import 'local_jarvis_agent.dart';
import 'remote/remote_failure.dart';
import 'remote/remote_jarvis_api.dart';

/// Prefers [RemoteJarvisApi]; on transport failure falls back to ephemeral local.
class FailoverJarvisBackend implements JarvisBackend {
  FailoverJarvisBackend({
    RemoteJarvisApi? remote,
    SecureStore? secureStore,
    LocalCredentials? localCredentials,
    LocalJarvisAgent Function({
      required bool skipWelcome,
    })? offlineFactory,
    void Function()? onEnteredOffline,
  })  : _remote = remote ?? RemoteJarvisApi(),
        _secureStore = secureStore ?? SecureStore(),
        _localCredentials = localCredentials ?? LocalCredentials(),
        _offlineFactory = offlineFactory,
        _onEnteredOffline = onEnteredOffline;

  final RemoteJarvisApi _remote;
  final SecureStore _secureStore;
  final LocalCredentials _localCredentials;
  final LocalJarvisAgent Function({required bool skipWelcome})? _offlineFactory;
  final void Function()? _onEnteredOffline;

  LocalJarvisAgent? _offline;
  bool _offlineActive = false;

  /// True after a successful remote ask or non-empty remote history (mid-chat).
  bool _skipWelcomeOnCutover = false;

  /// True once transport failover engaged for this process/session.
  bool get offlineActive => _offlineActive;

  LocalJarvisAgent _createOffline({required bool skipWelcome}) {
    if (_offlineFactory != null) {
      return _offlineFactory(skipWelcome: skipWelcome);
    }
    return LocalJarvisAgent(
      secureStore: _secureStore,
      messageStore: MemoryMessageStore(),
      forceInitialState: skipWelcome ? ChatState.initialized : null,
    );
  }

  Future<void> _enterOffline({required bool skipWelcome}) async {
    if (_offlineActive) return;
    final hasKey = await _localCredentials.hasApiKey();
    if (!hasKey) {
      throw OfflineKeyRequiredException();
    }
    _offline = _createOffline(skipWelcome: skipWelcome);
    _offlineActive = true;
    _onEnteredOffline?.call();
  }

  /// Manual cutover (soft-wait "Go offline") while a remote ask may still be in flight.
  Future<void> forceEnterOffline() =>
      _enterOffline(skipWelcome: _skipWelcomeOnCutover);

  Future<T> _remoteOrOffline<T>({
    required Future<T> Function() remoteOp,
    required Future<T> Function(LocalJarvisAgent offline) offlineOp,
  }) async {
    if (_offlineActive) {
      return offlineOp(_offline!);
    }
    try {
      return await remoteOp();
    } catch (e) {
      if (!isFailoverCandidate(e)) rethrow;
      await _enterOffline(skipWelcome: _skipWelcomeOnCutover);
      return offlineOp(_offline!);
    }
  }

  @override
  Future<List<String>> ask(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
  }) {
    return _remoteOrOffline(
      remoteOp: () async {
        final replies = await _remote.ask(
          message,
          modelName: modelName,
          images: images,
        );
        _skipWelcomeOnCutover = true;
        return replies;
      },
      offlineOp: (o) => o.ask(message, modelName: modelName, images: images),
    );
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) {
    return _remoteOrOffline(
      remoteOp: () async {
        final history = await _remote.getMessageHistory(threadId: threadId);
        if (history.isNotEmpty) {
          _skipWelcomeOnCutover = true;
        }
        return history;
      },
      offlineOp: (o) => o.getMessageHistory(threadId: threadId),
    );
  }

  @override
  Future<void> resetSession({String? threadId}) {
    return _remoteOrOffline(
      remoteOp: () => _remote.resetSession(threadId: threadId),
      offlineOp: (o) => o.resetSession(threadId: threadId),
    );
  }

  @override
  Future<bool> individualCacheExists() {
    return _remoteOrOffline(
      remoteOp: () => _remote.individualCacheExists(),
      offlineOp: (o) => o.individualCacheExists(),
    );
  }
}
