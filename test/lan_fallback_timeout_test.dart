import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/remote/auth_service.dart';
import 'package:jarvis_app/agent/remote/endpoint.dart';
import 'package:jarvis_app/agent/remote/remote_failure.dart';
import 'package:jarvis_app/agent/remote/remote_jarvis_api.dart';
import 'package:jarvis_app/config/app_config.dart';

class _TokenAuth extends AuthService {
  _TokenAuth(this.token);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

class _Bases extends RemoteEndpoint {
  _Bases(this.bases);

  final List<String> bases;

  @override
  Future<List<String>> candidateBases() async => bases;
}

const _bases = [
  'http://jarvis-raspberry:8000',
  'http://jarvis-raspberry.local:8000',
];

/// Primary attempt fails immediately. The fallback request never completes,
/// so the call ends only when that attempt's timeout fires.
RemoteJarvisApi _hangingFallback(List<String> urls) {
  var calls = 0;
  return RemoteJarvisApi(
    auth: _TokenAuth('jwt-1'),
    endpoint: _Bases(_bases),
    httpClient: MockClient((request) async {
      calls++;
      urls.add(request.url.toString());
      if (calls == 1) {
        throw const SocketException('primary down');
      }
      return Completer<http.Response>().future;
    }),
  );
}

void main() {
  group('LAN fallback timeout', () {
    testWidgets('transcribe retries with remoteTranscribeTimeout', (
      tester,
    ) async {
      final urls = <String>[];
      final api = _hangingFallback(urls);
      Object? error;
      final pending = api
          .transcribeAudio(bytes: const [1, 2, 3], filename: 'note.m4a')
          .then(
            (_) {},
            onError: (Object e) {
              error = e;
            },
          );

      await tester.pump();
      expect(urls, [
        'http://jarvis-raspberry:8000/transcribe',
        'http://jarvis-raspberry.local:8000/transcribe',
      ]);
      expect(error, isNull);

      await tester.pump(AppConfig.lanFallbackTimeout);
      expect(error, isNull);

      await tester.pump(
        AppConfig.remoteTranscribeTimeout - AppConfig.lanFallbackTimeout,
      );
      expect(error, isA<JarvisRemoteException>());
      expect(
        (error! as JarvisRemoteException).kind,
        RemoteFailureKind.transport,
      );
      await pending;
    });

    testWidgets('ask retries with remoteAskTimeout', (tester) async {
      final urls = <String>[];
      final api = _hangingFallback(urls);
      Object? error;
      final pending = api
          .ask('hello', modelName: 'GPT_4O_MINI')
          .then(
            (_) {},
            onError: (Object e) {
              error = e;
            },
          );

      await tester.pump();
      expect(urls, [
        'http://jarvis-raspberry:8000/ask',
        'http://jarvis-raspberry.local:8000/ask',
      ]);
      expect(error, isNull);

      await tester.pump(AppConfig.lanFallbackTimeout);
      expect(error, isNull);

      await tester.pump(
        AppConfig.remoteAskTimeout - AppConfig.lanFallbackTimeout,
      );
      expect(error, isA<JarvisRemoteException>());
      expect(
        (error! as JarvisRemoteException).kind,
        RemoteFailureKind.transport,
      );
      await pending;
    });

    testWidgets('history fallback still stops at lanFallbackTimeout', (
      tester,
    ) async {
      final urls = <String>[];
      final api = _hangingFallback(urls);
      Object? error;
      final pending = api.getMessageHistory().then(
        (_) {},
        onError: (Object e) {
          error = e;
        },
      );

      await tester.pump();
      expect(urls, [
        'http://jarvis-raspberry:8000/message-history',
        'http://jarvis-raspberry.local:8000/message-history',
      ]);
      expect(error, isNull);

      await tester.pump(
        AppConfig.lanFallbackTimeout - const Duration(milliseconds: 1),
      );
      expect(error, isNull);

      await tester.pump(const Duration(milliseconds: 1));
      expect(error, isA<JarvisRemoteException>());
      expect(
        (error! as JarvisRemoteException).kind,
        RemoteFailureKind.transport,
      );
      await pending;
    });

    testWidgets('login fallback still stops at lanFallbackTimeout', (
      tester,
    ) async {
      var calls = 0;
      final auth = AuthService(
        endpoint: _Bases(_bases),
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            throw const SocketException('primary down');
          }
          return Completer<http.Response>().future;
        }),
      );
      bool? result;
      final pending = auth.login('user', 'secret').then((value) {
        result = value;
      });

      await tester.pump();
      expect(calls, 2);
      expect(result, isNull);

      await tester.pump(
        AppConfig.lanFallbackTimeout - const Duration(milliseconds: 1),
      );
      expect(result, isNull);

      await tester.pump(const Duration(milliseconds: 1));
      expect(result, isFalse);
      await pending;
    });

    test('transcribe fallback returns text after a transport error', () async {
      var calls = 0;
      final api = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(_bases),
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            throw const SocketException('primary down');
          }
          return http.Response(
            jsonEncode({'text': 'lights on'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await api.transcribeAudio(bytes: const [9], filename: 'note.m4a'),
        'lights on',
      );
      expect(calls, 2);
    });

    test('ask fallback returns the reply after a transport error', () async {
      var calls = 0;
      final api = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(_bases),
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            throw const SocketException('primary down');
          }
          return http.Response(
            jsonEncode({
              'response': ['done'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(await api.ask('hello', modelName: 'GPT_4O_MINI'), ['done']);
      expect(calls, 2);
    });
  });
}
