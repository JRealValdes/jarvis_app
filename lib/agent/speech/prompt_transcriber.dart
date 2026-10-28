import '../../config/app_config.dart';
import '../remote/remote_jarvis_api.dart';
import 'audio_payload.dart';
import 'audio_transcriber.dart';
import 'speech_route.dart';
import 'transcription_errors.dart';

/// Jarvis `POST /transcribe` adapter for [PromptTranscriber].
class RemoteAudioTranscriber implements AudioTranscriber {
  RemoteAudioTranscriber(this._api);

  final RemoteJarvisApi _api;

  @override
  Future<String> transcribe({
    required List<int> bytes,
    required String filename,
  }) {
    return _api.transcribeAudio(bytes: bytes, filename: filename);
  }
}

/// Routes a finished clip to Jarvis or on-device Whisper.
class PromptTranscriber {
  PromptTranscriber({
    required this.remote,
    required this.localForKey,
    int? maxBytes,
  }) : maxBytes = maxBytes ?? AppConfig.maxAudioUploadBytes;

  final AudioTranscriber remote;
  final AudioTranscriber Function(String apiKey) localForKey;
  final int maxBytes;

  Future<String> transcribe({
    required List<int> bytes,
    required String filename,
    required SpeechContext context,
  }) async {
    validateAudioPayload(
      sizeBytes: bytes.length,
      filename: filename,
      maxBytes: maxBytes,
    );
    final route = speechRouteFor(
      mode: context.mode,
      offlineActive: context.offlineActive,
    );
    if (route == SpeechRoute.local) {
      final key = context.openAiApiKey?.trim() ?? '';
      if (key.isEmpty) {
        throw const SpeechTranscriptionException(
          'OpenAI API key is missing. Open Settings and paste your key.',
        );
      }
      return localForKey(key).transcribe(bytes: bytes, filename: filename);
    }
    return remote.transcribe(bytes: bytes, filename: filename);
  }
}
