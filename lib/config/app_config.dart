/// App-wide defaults for Jarvis (local and remote modes).
class AppConfig {
  AppConfig._();

  /// Default execution mode when nothing is stored yet.
  static const String defaultMode = 'auto';

  /// Short probe / remote call timeout before treating the server as down
  /// (login, history, reset — not LLM `/ask`).
  static const Duration remoteTransportTimeout = Duration(seconds: 8);

  /// Hard ceiling for remote `/ask` (LLM turns can exceed the transport probe).
  static const Duration remoteAskTimeout = Duration(seconds: 120);

  /// After this wait on `/ask`, offer Keep waiting / Go offline (Auto).
  static const Duration remoteAskSoftWait = Duration(seconds: 12);

  /// Hard ceiling for `POST /transcribe` (Whisper can outlast the transport probe).
  static const Duration remoteTranscribeTimeout = Duration(seconds: 60);

  /// OpenAI Whisper upload limit. Jarvis `POST /transcribe` enforces the same cap.
  static const int maxAudioUploadBytes = 25 * 1024 * 1024;

  /// One-shot LAN mDNS/hostname fallback when the configured primary URL fails.
  ///
  /// Override at build time, e.g.:
  /// `flutter run --dart-define=JARVIS_LAN_FALLBACK_URL=http://192.168.1.10:8000`
  /// Empty string disables the fallback. Not a secret — LAN topology only.
  static const String lanFallbackBaseUrl = String.fromEnvironment(
    'JARVIS_LAN_FALLBACK_URL',
    defaultValue: 'http://jarvis-raspberry.local:8000',
  );

  /// Tight timeout for the optional LAN fallback attempt (avoid mDNS hangs).
  static const Duration lanFallbackTimeout = Duration(seconds: 2);

  /// OpenAI model id used when the user has not chosen one.
  static const String defaultOpenAiModel = 'gpt-4o-mini';

  /// Remote FastAPI `ModelEnum` member name (must match server default /
  /// checkpointer key so `/ask` history and cache-status stay aligned).
  static const String defaultRemoteModelEnum = 'GPT_4O_MINI';

  /// OpenAI Chat Completions endpoint.
  static const String openAiChatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';

  /// On-device speech-to-text. Local and offline modes must not call `/transcribe`.
  static const String openAiAudioTranscriptionsUrl =
      'https://api.openai.com/v1/audio/transcriptions';

  /// Whisper model shared with Jarvis `POST /transcribe`.
  static const String whisperModel = 'whisper-1';

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
