import '../../domain/models/jarvis_mode.dart';

/// Where a finished mic clip is transcribed.
enum SpeechRoute {
  /// Jarvis `POST /transcribe` (Remote, and Auto while online).
  remote,

  /// OpenAI Whisper with the Settings key. Never calls Jarvis.
  local,
}

/// Remote / Auto-online use Jarvis. Local and Auto-offline stay on device.
SpeechRoute speechRouteFor({
  required JarvisMode mode,
  required bool offlineActive,
}) {
  switch (mode) {
    case JarvisMode.local:
      return SpeechRoute.local;
    case JarvisMode.remote:
      return SpeechRoute.remote;
    case JarvisMode.auto:
      return offlineActive ? SpeechRoute.local : SpeechRoute.remote;
  }
}

/// Live mode snapshot used when a clip is finished.
class SpeechContext {
  const SpeechContext({
    required this.mode,
    required this.offlineActive,
    required this.openAiApiKey,
  });

  final JarvisMode mode;
  final bool offlineActive;
  final String? openAiApiKey;
}
