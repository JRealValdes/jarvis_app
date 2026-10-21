import '../config/app_config.dart';
import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import 'backend_factory.dart';
import 'jarvis_backend.dart';
import 'remote/auth_service.dart';

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
  })  : _factory = factory ?? BackendFactory(),
        _secureStore = secureStore ?? SecureStore(),
        _auth = auth ?? AuthService();

  final BackendFactory _factory;
  final SecureStore _secureStore;
  final AuthService _auth;

  final List<ChatBubble> messages = [];

  JarvisBackend? _backend;
  JarvisMode mode = JarvisMode.local;
  String modelName = AppConfig.defaultOpenAiModel;
  bool isAdmin = false;
  bool loading = false;
  bool sending = false;

  Future<void> bootstrap({void Function()? onUpdate}) async {
    mode = await _secureStore.getMode();
    modelName = mode == JarvisMode.remote
        ? AppConfig.defaultRemoteModelEnum
        : await _secureStore.getOpenAiModel();
    _backend = await _factory.create();
    isAdmin = mode == JarvisMode.remote && await _auth.isAdmin();
    onUpdate?.call();
    await refresh(onUpdate: onUpdate);
  }

  Future<void> refresh({void Function()? onUpdate}) async {
    final backend = _backend;
    if (backend == null) return;

    loading = true;
    messages.clear();
    onUpdate?.call();

    try {
      final history = await backend.getMessageHistory();
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
    } catch (_) {
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
      } catch (e) {
        messages.add(ChatBubble(text: 'Reset failed: $e', isUser: false));
        onUpdate?.call();
        return;
      }
    } else {
      payload = (text ?? '').trim();
      if (payload.isEmpty) return;
      messages.add(ChatBubble(text: payload, isUser: true));
    }

    sending = true;
    onUpdate?.call();
    try {
      final responses = await backend.ask(payload, modelName: modelName);
      for (final msg in responses) {
        messages.add(ChatBubble(text: msg, isUser: false));
      }
    } catch (e) {
      messages.add(ChatBubble(text: 'Error: $e', isUser: false));
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
