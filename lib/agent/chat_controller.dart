import 'dart:async';
import 'dart:typed_data';

import '../config/app_config.dart';
import '../data/secure_store.dart';
import '../domain/chat_image.dart';
import '../domain/models/jarvis_mode.dart';
import 'backend_factory.dart';
import 'failover_jarvis_backend.dart';
import 'jarvis_backend.dart';
import 'openai/openai_errors.dart';
import 'remote/auth_service.dart';
import 'remote/remote_failure.dart';

/// Thumbnail or audio chip shown on a user bubble for the turn just sent.
class ChatBubbleMedia {
  const ChatBubbleMedia.image({
    required this.bytes,
    required this.label,
  }) : isImage = true;

  const ChatBubbleMedia.audio({required this.label})
      : isImage = false,
        bytes = null;

  final bool isImage;
  final Uint8List? bytes;
  final String label;
}

/// One bubble shown in the chat list (UI-facing).
class ChatBubble {
  const ChatBubble({
    required this.text,
    required this.isUser,
    this.media = const [],
  });

  final String text;
  final bool isUser;

  /// Live attachments. History reloads have none; image turns use a text marker.
  final List<ChatBubbleMedia> media;
}

/// Owns chat orchestration so [ChatScreen] stays mostly presentation.
class ChatController {
  ChatController({
    BackendFactory? factory,
    SecureStore? secureStore,
    AuthService? auth,
    Duration? askSoftWait,
  })  : _secureStore = secureStore ?? SecureStore(),
        _auth = auth ?? AuthService(),
        _askSoftWait = askSoftWait ?? AppConfig.remoteAskSoftWait {
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
  final Duration _askSoftWait;

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

  /// Soft-wait banner: server is slow on `/ask`.
  bool slowRemoteOfferVisible = false;

  /// Auto: show Go offline; Remote only: Keep waiting only.
  bool get slowRemoteCanGoOffline =>
      mode == JarvisMode.auto && !offlineActive;

  int _askGeneration = 0;
  String? _pendingAskPayload;
  List<ChatImage> _pendingImages = const [];
  Timer? _softWaitTimer;
  void Function()? _onUpdate;

  FailoverJarvisBackend? get _failover =>
      _backend is FailoverJarvisBackend ? _backend as FailoverJarvisBackend : null;

  Future<void> bootstrap({void Function()? onUpdate}) async {
    mode = await _secureStore.getMode();
    offlineActive = false;
    needsOfflineKey = false;
    _clearSlowOffer();
    modelName = mode == JarvisMode.local
        ? await _secureStore.getOpenAiModel()
        : AppConfig.defaultRemoteModelEnum;
    if (mode == JarvisMode.auto) {
      modelName = AppConfig.defaultRemoteModelEnum;
    }
    _backend = await _factory.create();
    isAdmin = (mode == JarvisMode.remote || mode == JarvisMode.auto) &&
        await _auth.isAdmin();
    onUpdate?.call();
    await refresh(onUpdate: onUpdate);
    _syncOfflineFlag();
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

  void _clearSlowOffer() {
    _softWaitTimer?.cancel();
    _softWaitTimer = null;
    slowRemoteOfferVisible = false;
  }

  void keepWaitingOnRemote({void Function()? onUpdate}) {
    slowRemoteOfferVisible = false;
    _softWaitTimer?.cancel();
    _softWaitTimer = null;
    (onUpdate ?? _onUpdate)?.call();
  }

  /// Auto: abandon in-flight remote ask and answer offline.
  Future<void> switchToOfflineNow({void Function()? onUpdate}) async {
    final notify = onUpdate ?? _onUpdate;
    final failover = _failover;
    final payload = _pendingAskPayload;
    if (failover == null || payload == null || offlineActive) {
      keepWaitingOnRemote(onUpdate: notify);
      return;
    }

    _askGeneration++;
    _clearSlowOffer();
    try {
      await failover.forceEnterOffline();
    } on OfflineKeyRequiredException catch (e) {
      needsOfflineKey = true;
      messages.add(ChatBubble(text: e.message, isUser: false));
      sending = false;
      notify?.call();
      return;
    }

    offlineActive = true;
    modelName = await _secureStore.getOpenAiModel();
    notify?.call();

    try {
      final responses = await failover.ask(
        payload,
        modelName: modelName,
        images: _pendingImages,
      );
      for (final msg in responses) {
        messages.add(ChatBubble(text: msg, isUser: false));
      }
    } on OfflineKeyRequiredException catch (e) {
      needsOfflineKey = true;
      messages.add(ChatBubble(text: e.message, isUser: false));
    } catch (e) {
      messages.add(ChatBubble(text: describeOpenAiError(e), isUser: false));
    } finally {
      sending = false;
      _pendingAskPayload = null;
      _pendingImages = const [];
      notify?.call();
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
  ///
  /// [visibleText] is the typed prompt. Audio transcripts stay in [text] only.
  /// [images] may be sent with an empty [text]. Remote turns with images use
  /// `GPT_4O_MINI` (the vision model). Local keeps the Settings model.
  Future<void> send({
    String? text,
    String? visibleText,
    bool initial = false,
    List<ChatImage> images = const [],
    List<ChatBubbleMedia> media = const [],
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
      if (payload.isEmpty && images.isEmpty) return;
      final shown = (visibleText ?? payload).trim();
      messages.add(
        ChatBubble(text: shown, isUser: true, media: List.of(media)),
      );
    }

    sending = true;
    needsOfflineKey = false;
    _pendingAskPayload = payload;
    _pendingImages = List<ChatImage>.of(images);
    _onUpdate = onUpdate;
    _clearSlowOffer();
    final gen = ++_askGeneration;
    onUpdate?.call();

    final useSoftWait = !offlineActive &&
        (mode == JarvisMode.auto || mode == JarvisMode.remote) &&
        !initial;

    if (useSoftWait) {
      _softWaitTimer = Timer(_askSoftWait, () {
        if (gen != _askGeneration || !sending || offlineActive) return;
        slowRemoteOfferVisible = true;
        onUpdate?.call();
      });
    }

    try {
      if (offlineActive && mode == JarvisMode.auto) {
        modelName = await _secureStore.getOpenAiModel();
      }
      final responses = await backend.ask(
        payload,
        modelName: _modelForAsk(images),
        images: images,
      );
      if (gen != _askGeneration) return;
      _syncOfflineFlag();
      if (offlineActive && mode == JarvisMode.auto) {
        modelName = await _secureStore.getOpenAiModel();
      }
      for (final msg in responses) {
        messages.add(ChatBubble(text: msg, isUser: false));
      }
    } on OfflineKeyRequiredException catch (e) {
      if (gen != _askGeneration) return;
      needsOfflineKey = true;
      messages.add(ChatBubble(text: e.message, isUser: false));
    } catch (e) {
      if (gen != _askGeneration) return;
      if (classifyRemoteFailure(e) == RemoteFailureKind.auth) {
        messages.add(
          ChatBubble(
            text: 'Remote authentication failed. Please log in again. ($e)',
            isUser: false,
          ),
        );
      } else if (e is JarvisRemoteException && e.message.trim().isNotEmpty) {
        messages.add(ChatBubble(text: e.message, isUser: false));
      } else {
        messages.add(ChatBubble(text: describeOpenAiError(e), isUser: false));
      }
    } finally {
      if (gen == _askGeneration) {
        _clearSlowOffer();
        sending = false;
        _pendingAskPayload = null;
        _pendingImages = const [];
        onUpdate?.call();
      }
    }
  }

  /// Remote vision is `GPT_4O_MINI` only. On-device turns keep Settings.
  String _modelForAsk(List<ChatImage> images) {
    if (images.isEmpty) return modelName;
    final onDevice = mode == JarvisMode.local || offlineActive;
    if (!onDevice) return AppConfig.defaultRemoteModelEnum;
    return modelName;
  }

  Future<void> resetChat({void Function()? onUpdate}) async {
    final backend = _backend;
    if (backend == null) return;
    _askGeneration++;
    _clearSlowOffer();
    await backend.resetSession();
    messages.clear();
    onUpdate?.call();
    await send(initial: true, onUpdate: onUpdate);
  }

  Future<void> logoutRemote() => _auth.logout();
}
