import '../openai/openai_errors.dart';
import '../remote/remote_failure.dart';

/// Validation or dictation failure with copy safe to show in a snackbar.
class SpeechTranscriptionException implements Exception {
  const SpeechTranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Microphone permission was denied or is blocked in system settings.
class MicPermissionDeniedException implements Exception {
  const MicPermissionDeniedException([
    this.message =
        'Microphone permission is required to dictate a prompt. '
        'Enable the microphone for Jarvis in system settings.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// User-facing copy for a failed dictation.
String describeTranscriptionError(Object error) {
  if (error is MicPermissionDeniedException) return error.message;
  if (error is SpeechTranscriptionException) return error.message;
  if (error is JarvisRemoteException) {
    if (error.kind == RemoteFailureKind.auth ||
        error.statusCode == 401 ||
        error.statusCode == 403) {
      return 'Remote authentication failed. Please log in again.';
    }
    if (error.kind == RemoteFailureKind.transport) {
      return 'Could not reach Jarvis to transcribe. Check the connection and try again.';
    }
    final detail = error.message.trim();
    if (detail.isNotEmpty) return detail;
    return 'Transcription failed. Try again.';
  }
  return describeOpenAiError(error);
}
