import '../config/app_config.dart';
import '../data/local_message_store.dart';
import '../data/message_store.dart';
import '../data/secure_store.dart';
import '../domain/chat_image.dart';
import '../domain/chat_state.dart';
import '../domain/models/chat_turn.dart';
import 'attachments/outgoing_ask.dart';
import 'jarvis_backend.dart';
import 'openai/openai_client.dart';
import 'session/jarvis_session.dart';
import 'tools/registry.dart';

/// On-device Jarvis: session state machine + OpenAI tools + local history.
class LocalJarvisAgent implements JarvisBackend {
  LocalJarvisAgent({
    SecureStore? secureStore,
    MessageStore? messageStore,
    OpenAiClient Function(String apiKey)? openAiFactory,
    ChatState? forceInitialState,
  })  : _secureStore = secureStore ?? SecureStore(),
        _store = messageStore ?? LocalMessageStore(),
        _openAiFactory = openAiFactory ?? ((key) => OpenAiClient(apiKey: key)),
        _forceInitialState = forceInitialState;

  final SecureStore _secureStore;
  final MessageStore _store;
  final OpenAiClient Function(String apiKey) _openAiFactory;

  /// When set (e.g. mid-chat offline cutover), skip welcome / seed flow.
  final ChatState? _forceInitialState;

  JarvisSession? _session;

  String get _threadId => AppConfig.localThreadId;

  @override
  Future<List<String>> ask(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
  }) async {
    final session = await _ensureSession(modelName: modelName);
    final replies = await session.ask(message, images: images);

    final uiTurns = <ChatTurn>[];
    final isWelcomeTurn = session.chatState == ChatState.jarvisWelcomeMessage;
    if (!isWelcomeTurn) {
      uiTurns.add(
        ChatTurn(
          role: 'user',
          content: historyUserContent(
            message: message,
            imageCount: images.length,
          ),
        ),
      );
    }
    for (final r in replies) {
      uiTurns.add(ChatTurn(role: 'assistant', content: r));
    }
    await _store.appendUiTurns(_threadId, uiTurns);
    await _persistSession(session);
    return replies;
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) async {
    final id = threadId ?? _threadId;
    return _store.getUiHistory(id);
  }

  @override
  Future<void> resetSession({String? threadId}) async {
    final id = threadId ?? _threadId;
    await _store.clearThread(id);
    _session?.reset();
    _session = null;
  }

  @override
  Future<bool> individualCacheExists() async {
    return _store.threadExists(_threadId);
  }

  Future<void> clearLocalConversation() => resetSession();

  Future<JarvisSession> _ensureSession({required String modelName}) async {
    if (_session != null) return _session!;

    final key = await _secureStore.getOpenAiApiKey();
    if (key == null || key.trim().isEmpty) {
      throw StateError(
        'OpenAI API key is missing. Open Settings and paste your key.',
      );
    }
    final profile = await _secureStore.getUserProfile();
    if (profile == null) {
      throw StateError('Local profile is missing. Complete Setup first.');
    }

    final storedModel =
        modelName.isNotEmpty ? modelName : await _secureStore.getOpenAiModel();

    final snapshot = await _store.loadThread(_threadId);
    ChatState initialState;
    List<Map<String, dynamic>>? llmMessages = snapshot?.llmMessages;
    if (_forceInitialState != null && snapshot == null) {
      initialState = _forceInitialState;
      llmMessages = null;
    } else {
      initialState = ChatState.notInitialized;
      if (snapshot != null) {
        initialState = JarvisSession.parseState(snapshot.chatState);
        // After a full LLM turn we have messages; reopen mid-flow as initialized.
        // Welcome-only leaves llm empty — keep welcome/starting so the next turn
        // injects the system prompt (STARTING_CHAT).
        if (snapshot.llmMessages.isNotEmpty &&
            (initialState == ChatState.jarvisWelcomeMessage ||
                initialState == ChatState.startingChat)) {
          initialState = ChatState.initialized;
        }
      }
    }

    _session = JarvisSession(
      threadId: _threadId,
      profile: profile,
      openAi: _openAiFactory(key),
      tools: builtInTools(),
      model: storedModel,
      initialState: initialState,
      llmMessages: llmMessages,
    );
    return _session!;
  }

  Future<void> _persistSession(JarvisSession session) async {
    await _store.saveThread(
      ThreadSnapshot(
        threadId: _threadId,
        chatState: session.stateStorageValue,
        llmMessages: session.llmMessages,
      ),
    );
  }
}
