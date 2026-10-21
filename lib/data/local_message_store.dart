import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models/chat_turn.dart';
import 'message_store.dart';

/// On-device sqflite persistence for UI history and LLM message blobs per thread.
class LocalMessageStore implements MessageStore {
  LocalMessageStore({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Database? _db;

  Future<Database> _database() async {
    if (_dbOverride != null) return _dbOverride;
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'jarvis_local.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ui_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            thread_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            seq INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE threads (
            thread_id TEXT PRIMARY KEY,
            chat_state TEXT NOT NULL,
            llm_messages_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  @override
  Future<bool> threadExists(String threadId) async {
    final db = await _database();
    final rows = await db.query(
      'threads',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<ChatTurn>> getUiHistory(String threadId) async {
    final db = await _database();
    final rows = await db.query(
      'ui_messages',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'seq ASC',
    );
    return rows
        .map(
          (r) => ChatTurn(
            role: r['role'] as String,
            content: r['content'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> appendUiTurns(String threadId, List<ChatTurn> turns) async {
    if (turns.isEmpty) return;
    final db = await _database();
    final existing = await db.rawQuery(
      'SELECT COALESCE(MAX(seq), -1) AS max_seq FROM ui_messages WHERE thread_id = ?',
      [threadId],
    );
    var seq = (existing.first['max_seq'] as int?) ?? -1;
    final batch = db.batch();
    for (final turn in turns) {
      seq += 1;
      batch.insert('ui_messages', {
        'thread_id': threadId,
        'role': turn.role,
        'content': turn.content,
        'seq': seq,
      });
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<ThreadSnapshot?> loadThread(String threadId) async {
    final db = await _database();
    final rows = await db.query(
      'threads',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final llm = jsonDecode(row['llm_messages_json'] as String) as List<dynamic>;
    return ThreadSnapshot(
      threadId: threadId,
      chatState: row['chat_state'] as String,
      llmMessages: llm.cast<Map<String, dynamic>>(),
    );
  }

  @override
  Future<void> saveThread(ThreadSnapshot snapshot) async {
    final db = await _database();
    await db.insert(
      'threads',
      {
        'thread_id': snapshot.threadId,
        'chat_state': snapshot.chatState,
        'llm_messages_json': jsonEncode(snapshot.llmMessages),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearThread(String threadId) async {
    final db = await _database();
    await db.delete('ui_messages', where: 'thread_id = ?', whereArgs: [threadId]);
    await db.delete('threads', where: 'thread_id = ?', whereArgs: [threadId]);
  }
}

class ThreadSnapshot {
  const ThreadSnapshot({
    required this.threadId,
    required this.chatState,
    required this.llmMessages,
  });

  final String threadId;
  final String chatState;
  final List<Map<String, dynamic>> llmMessages;
}
