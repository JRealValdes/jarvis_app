import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/failover_jarvis_backend.dart';
import 'package:jarvis_app/agent/jarvis_backend.dart';
import 'package:jarvis_app/agent/local_jarvis_agent.dart';
import 'package:jarvis_app/agent/remote/remote_failure.dart';
import 'package:jarvis_app/agent/remote/remote_jarvis_api.dart';
import 'package:jarvis_app/data/local_credentials.dart';
import 'package:jarvis_app/data/memory_message_store.dart';
import 'package:jarvis_app/domain/chat_image.dart';
import 'package:jarvis_app/domain/models/chat_turn.dart';

class _FakeOffline implements JarvisBackend {
  final replies = <String>[];
  List<ChatImage> lastImages = const [];

  @override
  Future<List<String>> ask(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
  }) async {
    replies.add(message);
    lastImages = images;
    return ['offline:$message'];
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) async => [];

  @override
  Future<bool> individualCacheExists() async => false;

  @override
  Future<void> resetSession({String? threadId}) async {}
}

class _CredsWithKey extends LocalCredentials {
  _CredsWithKey({required this.hasKey});

  final bool hasKey;

  @override
  Future<bool> hasApiKey() async => hasKey;
}

void main() {
  group('FailoverJarvisBackend', () {
    test('memory store does not share state across instances', () async {
      final a = MemoryMessageStore();
      final b = MemoryMessageStore();
      await a.appendUiTurns('local', [
        const ChatTurn(role: 'user', content: 'hi'),
      ]);
      expect(await a.getUiHistory('local'), hasLength(1));
      expect(await b.getUiHistory('local'), isEmpty);
      await a.clearThread('local');
      expect(await a.getUiHistory('local'), isEmpty);
    });

    test('transport failure + key → offline replies', () async {
      final offline = _FakeOffline();
      var entered = false;
      final backend = FailoverJarvisBackend(
        remote: _ThrowingRemote(
          JarvisRemoteException(
            'down',
            kind: RemoteFailureKind.transport,
          ),
        ),
        localCredentials: _CredsWithKey(hasKey: true),
        offlineFactory: ({required bool skipWelcome}) {
          return _AgentShim(offline);
        },
        onEnteredOffline: () => entered = true,
      );

      final replies = await backend.ask('hello', modelName: 'gpt-4o-mini');
      expect(replies, ['offline:hello']);
      expect(entered, isTrue);
      expect(backend.offlineActive, isTrue);
      expect(offline.replies, ['hello']);
    });

    test('transport failure forwards image attachments to offline', () async {
      final offline = _FakeOffline();
      const image = ChatImage(mediaType: 'image/png', dataBase64: 'abc');
      final backend = FailoverJarvisBackend(
        remote: _ThrowingRemote(
          JarvisRemoteException(
            'down',
            kind: RemoteFailureKind.transport,
          ),
        ),
        localCredentials: _CredsWithKey(hasKey: true),
        offlineFactory: ({required bool skipWelcome}) => _AgentShim(offline),
      );

      await backend.ask(
        'look',
        modelName: 'GPT_4O_MINI',
        images: const [image],
      );
      expect(offline.lastImages, [image]);
      expect(offline.replies, ['look']);
    });

    test('transport failure + no key → OfflineKeyRequiredException', () async {
      final backend = FailoverJarvisBackend(
        remote: _ThrowingRemote(
          JarvisRemoteException(
            'down',
            kind: RemoteFailureKind.transport,
          ),
        ),
        localCredentials: _CredsWithKey(hasKey: false),
        offlineFactory: ({required bool skipWelcome}) {
          return _AgentShim(_FakeOffline());
        },
      );

      expect(
        () => backend.ask('hello', modelName: 'gpt-4o-mini'),
        throwsA(isA<OfflineKeyRequiredException>()),
      );
      expect(backend.offlineActive, isFalse);
    });

    test('401 does not enter offline', () async {
      final backend = FailoverJarvisBackend(
        remote: _ThrowingRemote(
          JarvisRemoteException(
            'auth',
            statusCode: 401,
            kind: RemoteFailureKind.auth,
          ),
        ),
        localCredentials: _CredsWithKey(hasKey: true),
        offlineFactory: ({required bool skipWelcome}) {
          return _AgentShim(_FakeOffline());
        },
      );

      expect(
        () => backend.ask('hello', modelName: 'gpt-4o-mini'),
        throwsA(isA<JarvisRemoteException>()),
      );
      expect(backend.offlineActive, isFalse);
    });
  });
}

/// Minimal RemoteJarvisApi stand-in that only overrides ask via composition.
/// FailoverJarvisBackend types remote as RemoteJarvisApi — use a subclass.
class _ThrowingRemote extends RemoteJarvisApi {
  _ThrowingRemote(this.error);

  final Object error;

  @override
  Future<List<String>> ask(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
  }) async {
    // ignore: only_throw_errors
    throw error;
  }

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) async {
    // ignore: only_throw_errors
    throw error;
  }

  @override
  Future<bool> individualCacheExists() async {
    // ignore: only_throw_errors
    throw error;
  }

  @override
  Future<void> resetSession({String? threadId}) async {
    // ignore: only_throw_errors
    throw error;
  }
}

class _AgentShim extends LocalJarvisAgent {
  _AgentShim(this.inner) : super(messageStore: MemoryMessageStore());

  final JarvisBackend inner;

  @override
  Future<List<String>> ask(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
  }) =>
      inner.ask(message, modelName: modelName, images: images);

  @override
  Future<List<ChatTurn>> getMessageHistory({String? threadId}) =>
      inner.getMessageHistory(threadId: threadId);

  @override
  Future<bool> individualCacheExists() => inner.individualCacheExists();

  @override
  Future<void> resetSession({String? threadId}) =>
      inner.resetSession(threadId: threadId);
}
