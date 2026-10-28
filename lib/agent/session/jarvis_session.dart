import '../../domain/chat_image.dart';
import '../../domain/chat_state.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/prompts.dart';
import '../attachments/vision_content.dart';
import '../openai/openai_client.dart';
import '../openai/openai_errors.dart';
import '../tools/tool.dart';

/// Orchestrates a conversation turn: state, prompts, and LLM (ported from Python).
class JarvisSession {
  JarvisSession({
    required this.threadId,
    required this.profile,
    required this.openAi,
    required this.tools,
    required this.model,
    ChatState initialState = ChatState.notInitialized,
    List<Map<String, dynamic>>? llmMessages,
  })  : _chatState = initialState,
        llmMessages = List<Map<String, dynamic>>.from(llmMessages ?? const []);

  final String threadId;
  final UserProfile profile;
  final OpenAiClient openAi;
  final List<JarvisTool> tools;
  final String model;

  ChatState _chatState;
  ChatState get chatState => _chatState;

  /// Full OpenAI message history for this thread (excluding ephemeral turn injects
  /// that are only needed once at STARTING_CHAT — those are merged into this list
  /// after the first LLM call).
  final List<Map<String, dynamic>> llmMessages;

  /// Always true in local personal mode (profile replaces ID protocol).
  bool get validUser => true;

  Future<List<String>> ask(
    String prompt, {
    List<ChatImage> images = const [],
  }) async {
    _updateChatState();

    if (_chatState == ChatState.notInitialized) {
      return [automaticResponseIfIdFailed];
    }

    if (_chatState == ChatState.jarvisWelcomeMessage) {
      return [getWelcomeMessage(profile)];
    }

    try {
      if (images.isNotEmpty && !openAiModelSupportsImages(model)) {
        throw OpenAiException(
          'The selected model does not support images. '
          'Choose gpt-4o-mini in Settings.',
        );
      }
      final content = userMessageContent(prompt, images);
      if (_chatState == ChatState.startingChat) {
        final messages = prepareMessagesForVision(<Map<String, dynamic>>[
          {
            'role': 'system',
            'content': buildBackgroundPrompt(
              validUser: validUser,
              user: profile,
            ),
          },
          {
            'role': 'assistant',
            'content': getWelcomeMessage(profile),
          },
          {
            'role': 'user',
            'content': content,
          },
        ]);
        final result = await openAi.completeWithTools(
          model: model,
          messages: messages,
          tools: tools,
        );
        llmMessages
          ..clear()
          ..addAll(result.messages);
        return result.assistantTexts;
      }

      if (_chatState == ChatState.initialized) {
        final messages = prepareMessagesForVision(
          List<Map<String, dynamic>>.from(llmMessages)
            ..add({'role': 'user', 'content': content}),
        );
        final result = await openAi.completeWithTools(
          model: model,
          messages: messages,
          tools: tools,
        );
        llmMessages
          ..clear()
          ..addAll(result.messages);
        return result.assistantTexts;
      }
    } catch (e) {
      return [describeOpenAiError(e)];
    }

    return [automaticResponseIfIdFailed];
  }

  void _updateChatState() {
    const wasPreviouslyInvalid = false;
    _chatState = computeNextChatState(
      _chatState,
      validUser: validUser,
      wasPreviouslyInvalid: wasPreviouslyInvalid,
    );
  }

  void reset() {
    _chatState = ChatState.notInitialized;
    llmMessages.clear();
  }

  static ChatState parseState(String raw) {
    switch (raw) {
      case 'jarvisWelcomeMessage':
        return ChatState.jarvisWelcomeMessage;
      case 'startingChat':
        return ChatState.startingChat;
      case 'initialized':
        return ChatState.initialized;
      case 'notInitialized':
      default:
        return ChatState.notInitialized;
    }
  }

  String get stateStorageValue => _chatState.name;
}
