/// Execution mode for the Jarvis app.
enum JarvisMode {
  /// Prefer remote when reachable; on-device OpenAI only on transport failure.
  auto,

  /// On-device agent calling OpenAI directly (disk-backed history).
  local,

  /// Home/cloud FastAPI backend only (no offline failover).
  remote;

  static JarvisMode fromStorage(String? value) {
    switch (value) {
      case 'remote':
        return JarvisMode.remote;
      case 'local':
        return JarvisMode.local;
      case 'auto':
        return JarvisMode.auto;
      default:
        return JarvisMode.auto;
    }
  }

  String get storageValue => name;

  String get displayLabel {
    switch (this) {
      case JarvisMode.auto:
        return 'Auto (remote preferred)';
      case JarvisMode.local:
        return 'Local only';
      case JarvisMode.remote:
        return 'Remote only';
    }
  }
}
