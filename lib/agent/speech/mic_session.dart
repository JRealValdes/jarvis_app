/// One live microphone capture. Implementations own the platform recorder.
abstract class MicSession {
  Future<bool> hasPermission();

  Future<void> start({required String path});

  Future<void> pause();

  Future<void> resume();

  /// Stops and returns the clip path. Null when nothing was captured.
  Future<String?> stop();

  /// Stops and discards the platform clip.
  Future<void> cancel();

  Future<void> dispose();
}
