/// App-wide defaults for Jarvis (local and remote modes).
class AppConfig {
  AppConfig._();

  /// Default execution mode when nothing is stored yet.
  static const String defaultMode = 'auto';

  /// Short probe / remote call timeout before treating the server as down.
  static const Duration remoteTransportTimeout = Duration(seconds: 8);

  /// OpenAI model id used when the user has not chosen one.
  static const String defaultOpenAiModel = 'gpt-4o-mini';

  /// Remote FastAPI `ModelEnum` member name (must match server default /
  /// checkpointer key so `/ask` history and cache-status stay aligned).
  static const String defaultRemoteModelEnum = 'GPT_4O_MINI';

  /// OpenAI Chat Completions endpoint.
  static const String openAiChatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';

  /// Maps legacy / UI model labels to OpenAI model ids.
  static String resolveOpenAiModelId(String modelName) {
    switch (modelName) {
      case 'GPT_3_5':
      case 'gpt-3.5-turbo':
        return 'gpt-3.5-turbo';
      case 'GPT_4O_MINI':
      case 'gpt-4o-mini':
        return 'gpt-4o-mini';
      default:
        return modelName;
    }
  }

  static const List<String> openAiModelChoices = [
    'gpt-4o-mini',
    'gpt-3.5-turbo',
  ];

  /// Local conversation thread id (single-user personal app).
  static const String localThreadId = 'local';

  /// Hidden seed turn used to advance ChatState on an empty thread.
  static const String seedUserMessage = 'Hello';
}
