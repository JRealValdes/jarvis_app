import 'package:path/path.dart' as p;

import '../../config/app_config.dart';
import 'transcription_errors.dart';

/// Extensions Jarvis `POST /transcribe` and OpenAI Whisper both accept.
const supportedAudioExtensions = <String>[
  '.flac',
  '.m4a',
  '.mp3',
  '.mp4',
  '.mpeg',
  '.mpga',
  '.oga',
  '.ogg',
  '.wav',
  '.webm',
];

/// Reject empty, oversized, or unsupported clips before any network call.
void validateAudioPayload({
  required int sizeBytes,
  required String filename,
  int maxBytes = AppConfig.maxAudioUploadBytes,
}) {
  final name = p.basename(filename).trim();
  if (name.isEmpty || name == '.' || name == '..') {
    throw const SpeechTranscriptionException('Audio filename is required.');
  }
  final ext = p.extension(name).toLowerCase();
  if (!supportedAudioExtensions.contains(ext)) {
    final allowed = supportedAudioExtensions.join(', ');
    final shown = ext.isEmpty ? '(none)' : ext;
    throw SpeechTranscriptionException(
      "Unsupported audio format '$shown'. Allowed: $allowed.",
    );
  }
  if (sizeBytes <= 0) {
    throw const SpeechTranscriptionException('Audio file is empty.');
  }
  if (sizeBytes > maxBytes) {
    throw SpeechTranscriptionException(
      'Audio exceeds max size of $maxBytes bytes.',
    );
  }
}
