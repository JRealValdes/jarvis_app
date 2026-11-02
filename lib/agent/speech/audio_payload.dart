import 'package:path/path.dart' as p;

import '../../config/app_config.dart';
import 'transcription_errors.dart';

/// Extensions Jarvis `POST /transcribe` accepts (aligned with backend).
///
/// Whisper does not list `.opus`; see [whisperUploadFilename].
const supportedAudioExtensions = <String>[
  '.flac',
  '.m4a',
  '.mp3',
  '.mp4',
  '.mpeg',
  '.mpga',
  '.oga',
  '.ogg',
  '.opus',
  '.wav',
  '.webm',
];

/// Whisper documents ogg, not opus. WhatsApp voice notes are Ogg Opus as `.opus`.
const whisperExtensionAliases = <String, String>{
  '.opus': '.ogg',
};

/// Basename Whisper should see for an accepted audio file.
///
/// Maps extensions Whisper does not list (e.g. `.opus`) to a documented
/// container when the bytes are typically compatible (Ogg Opus). UI labels and
/// Jarvis `/transcribe` keep the original name.
String whisperUploadFilename(String filename) {
  final name = p.basename(filename);
  final ext = p.extension(name).toLowerCase();
  final mapped = whisperExtensionAliases[ext];
  if (mapped == null) return name;
  final stem = name.substring(0, name.length - ext.length);
  return '$stem$mapped';
}

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
