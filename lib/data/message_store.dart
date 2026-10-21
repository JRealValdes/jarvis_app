import '../domain/models/chat_turn.dart';
import 'local_message_store.dart' show ThreadSnapshot;

/// Persistence for UI history + LLM session blobs (disk or memory).
abstract class MessageStore {
  Future<bool> threadExists(String threadId);

  Future<List<ChatTurn>> getUiHistory(String threadId);

  Future<void> appendUiTurns(String threadId, List<ChatTurn> turns);

  Future<ThreadSnapshot?> loadThread(String threadId);

  Future<void> saveThread(ThreadSnapshot snapshot);

  Future<void> clearThread(String threadId);
}
