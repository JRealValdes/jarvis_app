/// Execution mode for the Jarvis app.
enum JarvisMode {
  /// On-device agent calling OpenAI directly.
  local,

  /// Home/cloud FastAPI backend.
  remote;

  static JarvisMode fromStorage(String? value) {
    switch (value) {
      case 'remote':
        return JarvisMode.remote;
      case 'local':
      default:
        return JarvisMode.local;
    }
  }

  String get storageValue => name;
}
