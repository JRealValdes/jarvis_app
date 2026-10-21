import '../domain/models/chat_turn.dart';

/// Facade shared by ChatScreen for local and remote backends.
abstract class JarvisBackend {
  Future<List<String>> ask(String message, {required String modelName});

  Future<List<ChatTurn>> getMessageHistory({String? threadId});

  Future<void> resetSession({String? threadId});

  Future<bool> individualCacheExists();
}

/// Admin-only operations (remote FastAPI).
abstract class JarvisAdminBackend {
  Future<CacheStatus> getCacheStatus();

  Future<void> resetGlobalMemory();

  Future<void> resetSession({String? threadId});
}

class CacheStatus {
  const CacheStatus({
    required this.agentModels,
    required this.sessions,
  });

  final List<String> agentModels;

  /// Pairs of (model, threadId).
  final List<(String, String)> sessions;
}
