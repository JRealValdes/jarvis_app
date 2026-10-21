import '../domain/models/chat_turn.dart';
import 'local_message_store.dart' show ThreadSnapshot;
import 'message_store.dart';

/// Ephemeral in-memory store for offline failover turns (cleared on process death).
class MemoryMessageStore implements MessageStore {
  final Map<String, List<ChatTurn>> _ui = {};
  final Map<String, ThreadSnapshot> _threads = {};

  @override
  Future<bool> threadExists(String threadId) async =>
      _threads.containsKey(threadId);

  @override
  Future<List<ChatTurn>> getUiHistory(String threadId) async =>
      List.unmodifiable(_ui[threadId] ?? const []);

  @override
  Future<void> appendUiTurns(String threadId, List<ChatTurn> turns) async {
    if (turns.isEmpty) return;
    final list = _ui.putIfAbsent(threadId, () => <ChatTurn>[]);
    list.addAll(turns);
  }

  @override
  Future<ThreadSnapshot?> loadThread(String threadId) async =>
      _threads[threadId];

  @override
  Future<void> saveThread(ThreadSnapshot snapshot) async {
    _threads[snapshot.threadId] = snapshot;
  }

  @override
  Future<void> clearThread(String threadId) async {
    _ui.remove(threadId);
    _threads.remove(threadId);
  }
}
