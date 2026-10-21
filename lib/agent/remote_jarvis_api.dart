import 'dart:convert';

import '../domain/models/chat_turn.dart';
import 'jarvis_backend.dart';
import 'remote_api_client.dart';
import 'remote_cache_parsing.dart';

/// Remote FastAPI backend (home/cloud server).
class RemoteJarvisApi implements JarvisBackend, JarvisAdminBackend {
  RemoteJarvisApi({RemoteApiClient? api}) : _api = api ?? RemoteApiClient();

  final RemoteApiClient _api;

  @override
  Future<List<String>> ask(String message, {required String modelName}) async {
    final resp = await _api.postAsk({
      'message': message,
      'model_name': modelName,
    });
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Ask failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    return List<String>.from(decoded['response'] ?? []);
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) async {
    final resp = await _api.getMessageHistory(threadId: threadId);
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('History failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final history = decoded['messages'] as List<dynamic>? ?? [];
    return history
        .map((m) => ChatTurn.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  @override
  Future<void> resetSession({String? threadId}) async {
    final resp = await _api.resetSession(threadId: threadId);
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Reset failed: ${resp.statusCode}');
    }
  }

  @override
  Future<bool> individualCacheExists() async {
    return _api.getIndividualCacheExists();
  }

  @override
  Future<CacheStatus> getCacheStatus() async {
    final resp = await _api.getCacheStatus();
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Cache status failed: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final models = List<String>.from(data['agent_models'] ?? []);
    final sessions = parseCacheSessionList(data['sessions'] as List<dynamic>? ?? []);
    return CacheStatus(agentModels: models, sessions: sessions);
  }

  @override
  Future<void> resetGlobalMemory() async {
    final resp = await _api.resetGlobalMemory();
    if (resp.statusCode != 200) {
      throw JarvisRemoteException('Global reset failed: ${resp.statusCode}');
    }
  }
}

class JarvisRemoteException implements Exception {
  JarvisRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}
