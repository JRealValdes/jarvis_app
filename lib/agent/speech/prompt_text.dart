/// Inserts [spoken] into the composer without wiping an existing draft.
String mergeDictationIntoPrompt(String existing, String spoken) {
  final text = spoken.trim();
  if (text.isEmpty) return existing;
  if (existing.trim().isEmpty) return text;
  final separator =
      existing.endsWith(' ') || existing.endsWith('\n') ? '' : ' ';
  return '$existing$separator$text';
}

/// `mm:ss` clock for the recording bar.
String formatRecordingClock(Duration elapsed) {
  final total = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
