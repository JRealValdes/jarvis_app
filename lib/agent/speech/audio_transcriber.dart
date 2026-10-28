/// Turns one audio clip into text.
abstract class AudioTranscriber {
  Future<String> transcribe({
    required List<int> bytes,
    required String filename,
  });
}
