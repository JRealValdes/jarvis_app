/// Parses admin cache `sessions` entries from Jarvis FastAPI.
///
/// The server currently returns `str((model_name, thread_id))` Python tuples,
/// e.g. `('GPT_4O_MINI', 'jose')`. Prefer structured JSON later on the backend.
(String, String)? parseCacheSessionEntry(String raw) {
  final quoted = RegExp(r"^\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)$").firstMatch(raw.trim());
  if (quoted != null) {
    return (quoted.group(1)!, quoted.group(2)!);
  }

  final cleaned = raw.replaceAll(RegExp(r"[()']"), '');
  final parts = cleaned.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) return null;
  return (list[0], list.length > 1 ? list[1] : '');
}

/// Maps a list of raw session strings to `(model, threadId)` pairs, dropping junk.
List<(String, String)> parseCacheSessionList(Iterable<dynamic> raw) {
  final out = <(String, String)>[];
  for (final entry in raw) {
    final parsed = parseCacheSessionEntry(entry.toString());
    if (parsed != null) out.add(parsed);
  }
  return out;
}
