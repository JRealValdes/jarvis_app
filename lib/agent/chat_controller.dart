import '../config/app_config.dart';
import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import 'backend_factory.dart';
import 'failover_jarvis_backend.dart';
import 'jarvis_backend.dart';
import 'remote/auth_service.dart';
import 'remote/remote_failure.dart';

/// One bubble shown in the chat list (UI-facing).
class ChatBubble {
  const ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// Owns chat orchestration so [ChatScreen] stays mostly presentation.
class ChatController {
  ChatController({
    BackendFactory? factory,
    SecureStore? secureStore,
    AuthService? auth,
  })  : _secureStore = secureStore ?? SecureStore(),
        _auth = auth ?? AuthService() {
    _factory = factory ??
        BackendFactory(
          secureStore: _secureStore,
          onEnteredOffline: () {
            offlineActive = true;
          },
        );
  }

  late final BackendFactory _factory;
  final SecureStore _secureStore;
  final AuthService _auth;

  final List<ChatBubble> messages = [];

  JarvisBackend? _backend;
  JarvisMode mode = JarvisMode.auto;
  String modelName = AppConfig.defaultOpenAiModel;
  bool isAdmin = false;
  bool loading = false;
  bool sending = false;

  /// Auto-mode: remote transport failed; offline agent is answering.
  bool offlineActive = false;

  /// Last send blocked because offline was needed and no API key is set.
  bool needsOfflineKey = false;

  FailoverJarvisBackend? get _failover =>
      _backend is FailoverJarvisBackend ? _backend as FailoverJarvisBackend : null;

  Future<void> bootstrap({void Function()? onUpdate}) async {
    mode = await _secureStore.getMode();
    offlineActive = false;
    needsOfflineKey = false;
    modelName = mode == JarvisMode.local
        ? await _secureStore.getOpenAiModel()
        : mode == JarvisMode.remote
            ? AppConfig.defaultRemoteModelEnum
            : AppConfig.defaultRemoteModelEnum;
    // Auto uses remote model enum while online; OpenAI id after cutover.
    if (mode == JarvisMode.auto) {
      modelName = AppConfig.defaultRemoteModelEnum;
    }
    _backend = await _factory.create();
    isAdmin = (mode == JarvisMode.remote || mode == JarvisMode.auto) &&
        await _auth.isAdmin();
    onUpdate?.call();
    await refresh(onUpdate: onUpdate);
    _syncOfflineFlag();
    // After cutover during refresh, switch model id for OpenAI.
    if (offlineActive && mode == JarvisMode.auto) {
      modelName = await _secureStore.getOpenAiModel();
    }
    onUpdate?.call();
  }

  void _syncOfflineFlag() {
    final f = _failover;
    if (f != null && f.offlineActive) {
      offlineActive = true;
    }
  }

  Future<void> refresh({void Function()? onUpdate}) async {
    final backend = _backend;
    if (backend == null) return;

    loading = true;
    messages.clear();
    onUpdate?.call();

    try {
      final history = await backend.getMessageHistory();
      _syncOfflineFlag();
      final cacheExists = await backend.individualCacheExists();

      if (history.isEmpty) {
        if (cacheExists) {
          await backend.resetSession();
        }
        loading = false;
        onUpdate?.call();
        await send(initial: true, onUpdate: onUpdate);
        return;
      }

      for (final msg in history) {
        if (msg.isSystem) continue;
        messages.add(ChatBubble(text: msg.content, isUser: msg.isUser));
      }
      loading = false;
      onUpdate?.call();
    } on OfflineKeyRequiredException catch (e) {
      loading = false;
      needsOfflineKey = true;
      messages.add(ChatBubble(text: e.message, isUser: false));
      onUpdate?.call();
    } catch (e) {
      if (classifyRemoteFailure(e) == RemoteFailureKind.auth) {
        loading = false;
        messages.add(
          ChatBubble(
            text: 'Remote authentication failed. Please log in again. ($e)',
            isUser: false,
          ),
        );
        onUpdate?.call();
        return;
      }
      loading = false;
      onUpdate?.call();
      await send(initial: true, onUpdate: onUpdate);
    }
  }

  /// Sends [text], or the seed turn when [initial] is true (not shown as user).
  Future<void> send({
    String? text,
    bool initial = false,
    void Function()? onUpdate,
  }) async {
    final backend = _backend;
    if (backend == null || sending) return;

    late final String payload;
    if (initial) {
      payload = AppConfig.seedUserMessage;
      try {
        await backend.resetSession();
      } on OfflineKeyRequiredException catch (e) {
        needsOfflineKey = true;
        messages.add(ChatBubble(text: e.message, isUser: false));
        onUpdate?.call();
        return;
      } catch (e) {
        if (classifyRemoteFailure(e) == RemoteFailureKind.auth) {
          messages.add(
            ChatBubble(
              text: 'Remote authentication failed. Please log in again. ($e)',
              isUser: false,
            ),
          );
          onUpdate?.call();
          return;
        }
        // Transport during reset: Failover may already have entered offline.
        _syncOfflineFlag();
        if (!offlineActive && isFailoverCandidate(e)) {
          messages.add(ChatBubble(text: 'Reset failed: $e', isUser: false));
          onUpdate?.call();
          return;
        }
        if (!offlineActive) {
          messages.add(ChatBubble(text: 'Reset failed: $e', isUser: false));
          onUpdate?.call();
          return;
        }
      }
    } else {
      payload = (text ?? '').trim();
      if (payload.isEmpty) return;
      messages.add(ChatBubble(text: payload, isUser: true));
    }

    sending = true;
    needsOfflineKey = false;
    onUpdate?.call();
    try {
      if (offlineActive && mode == JarvisMode.auto) {
        modelName = await _secureStore.getOpenAiModel();
      }
      final responses = await backend.ask(payload, modelName: modelName);
      _syncOfflineFlag();
      if (offlineActive && mode == JarvisMode.auto) {
        modelName = await _secureStore.getOpenAiModel();
      }
      for (final msg in responses) {
        messages.add(ChatBubble(text: msg, isUser: false));
      }
    } on OfflineKeyRequiredException catch (e) {
      needsOfflineKey = true;
      messages.add(ChatBubble(text: e.message, isUser: false));
    } catch (e) {
      if (classifyRemoteFailure(e) == RemoteFailureKind.auth) {
        messages.add(
          ChatBubble(
            text: 'Remote authentication failed. Please log in again. ($e)',
            isUser: false,
          ),
        );
      } else {
        messages.add(ChatBubble(text: 'Error: $e', isUser: false));
      }
    } finally {
      sending = false;
      onUpdate?.call();
    }
  }

  Future<void> resetChat({void Function()? onUpdate}) async {
    final backend = _backend;
    if (backend == null) return;
    await backend.resetSession();
    messages.clear();
    onUpdate?.call();
    await send(initial: true, onUpdate: onUpdate);
  }

  Future<void> logoutRemote() => _auth.logout();
}
