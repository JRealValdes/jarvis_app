import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/openai/openai_client.dart';
import 'package:jarvis_app/agent/remote/auth_service.dart';
import 'package:jarvis_app/agent/remote/endpoint.dart';
import 'package:jarvis_app/agent/remote/remote_failure.dart';
import 'package:jarvis_app/agent/remote/remote_jarvis_api.dart';
import 'package:jarvis_app/agent/speech/audio_payload.dart';
import 'package:jarvis_app/agent/speech/audio_transcriber.dart';
import 'package:jarvis_app/agent/speech/openai_whisper_client.dart';
import 'package:jarvis_app/agent/speech/prompt_text.dart';
import 'package:jarvis_app/agent/speech/prompt_transcriber.dart';
import 'package:jarvis_app/agent/speech/speech_route.dart';
import 'package:jarvis_app/agent/speech/transcription_errors.dart';
import 'package:jarvis_app/config/app_config.dart';
import 'package:jarvis_app/domain/models/jarvis_mode.dart';

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

class _Counting implements AudioTranscriber {
  _Counting(this.text);

  final String text;
  int calls = 0;
  List<int>? lastBytes;
  String? lastFilename;

  @override
  Future<String> transcribe({
    required List<int> bytes,
    required String filename,
  }) async {
    calls++;
    lastBytes = bytes;
    lastFilename = filename;
    return text;
  }
}

void main() {
  const clip = [1, 2, 3, 4];

  group('speechRouteFor', () {
    test('local and auto-offline stay on device', () {
      expect(
        speechRouteFor(mode: JarvisMode.local, offlineActive: false),
        SpeechRoute.local,
      );
      expect(
        speechRouteFor(mode: JarvisMode.auto, offlineActive: true),
        SpeechRoute.local,
      );
    });

    test('remote and auto-online use Jarvis', () {
      expect(
        speechRouteFor(mode: JarvisMode.remote, offlineActive: false),
        SpeechRoute.remote,
      );
      expect(
        speechRouteFor(mode: JarvisMode.auto, offlineActive: false),
        SpeechRoute.remote,
      );
    });
  });

  group('validateAudioPayload', () {
    test('rejects empty, oversized, and unsupported files', () {
      expect(
        () => validateAudioPayload(sizeBytes: 0, filename: 'clip.m4a'),
        throwsA(
          isA<SpeechTranscriptionException>().having(
            (e) => e.message,
            'message',
            'Audio file is empty.',
          ),
        ),
      );
      expect(
        () => validateAudioPayload(
          sizeBytes: 5,
          filename: 'clip.m4a',
          maxBytes: 4,
        ),
        throwsA(
          isA<SpeechTranscriptionException>().having(
            (e) => e.message,
            'message',
            'Audio exceeds max size of 4 bytes.',
          ),
        ),
      );
      expect(
        () => validateAudioPayload(sizeBytes: 4, filename: 'clip.txt'),
        throwsA(
          isA<SpeechTranscriptionException>().having(
            (e) => e.message,
            'message',
            contains("Unsupported audio format '.txt'"),
          ),
        ),
      );
    });
  });

  group('PromptTranscriber routing', () {
    test('local mode calls Whisper with the trimmed settings key', () async {
      final remote = _Counting('nope');
      String? seenKey;
      final transcriber = PromptTranscriber(
        remote: remote,
        localForKey: (key) {
          seenKey = key;
          return _Counting('lights on');
        },
      );

      final text = await transcriber.transcribe(
        bytes: clip,
        filename: 'jarvis-mic-1.m4a',
        context: const SpeechContext(
          mode: JarvisMode.local,
          offlineActive: false,
          openAiApiKey: '  sk-test  ',
        ),
      );

      expect(text, 'lights on');
      expect(seenKey, 'sk-test');
      expect(remote.calls, 0);
    });

    test('auto offline skips Jarvis even when a key is present', () async {
      final remote = _Counting('nope');
      var localCalls = 0;
      final transcriber = PromptTranscriber(
        remote: remote,
        localForKey: (key) {
          localCalls++;
          return _Counting('offline');
        },
      );

      final text = await transcriber.transcribe(
        bytes: clip,
        filename: 'clip.m4a',
        context: const SpeechContext(
          mode: JarvisMode.auto,
          offlineActive: true,
          openAiApiKey: 'sk-test',
        ),
      );

      expect(text, 'offline');
      expect(localCalls, 1);
      expect(remote.calls, 0);
    });

    test('auto online uses Jarvis and ignores the settings key', () async {
      final remote = _Counting('from server');
      final transcriber = PromptTranscriber(
        remote: remote,
        localForKey: (_) => throw StateError('local whisper must not run'),
      );

      final text = await transcriber.transcribe(
        bytes: clip,
        filename: 'clip.wav',
        context: const SpeechContext(
          mode: JarvisMode.auto,
          offlineActive: false,
          openAiApiKey: 'sk-test',
        ),
      );

      expect(text, 'from server');
      expect(remote.calls, 1);
      expect(remote.lastFilename, 'clip.wav');
    });

    test('missing local key does not call either transcriber', () async {
      final remote = _Counting('nope');
      var localCalls = 0;
      final transcriber = PromptTranscriber(
        remote: remote,
        localForKey: (_) {
          localCalls++;
          return _Counting('nope');
        },
      );

      expect(
        () => transcriber.transcribe(
          bytes: clip,
          filename: 'clip.m4a',
          context: const SpeechContext(
            mode: JarvisMode.local,
            offlineActive: false,
            openAiApiKey: '   ',
          ),
        ),
        throwsA(
          isA<SpeechTranscriptionException>().having(
            (e) => e.message,
            'message',
            contains('Open Settings'),
          ),
        ),
      );
      expect(remote.calls, 0);
      expect(localCalls, 0);
    });

    test('invalid audio is rejected before either client', () async {
      final remote = _Counting('nope');
      final transcriber = PromptTranscriber(
        remote: remote,
        localForKey: (_) => throw StateError('local whisper must not run'),
        maxBytes: 4,
      );

      expect(
        () => transcriber.transcribe(
          bytes: const [1, 2, 3, 4, 5],
          filename: 'clip.m4a',
          context: const SpeechContext(
            mode: JarvisMode.remote,
            offlineActive: false,
            openAiApiKey: null,
          ),
        ),
        throwsA(isA<SpeechTranscriptionException>()),
      );
      expect(remote.calls, 0);
    });
  });

  group('POST /transcribe', () {
    test('sends multipart file with bearer JWT and reads text', () async {
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'text': 'turn on the lights'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(['http://jarvis.test']),
        httpClient: mock,
      );

      final text = await api.transcribeAudio(
        bytes: clip,
        filename: 'note.m4a',
      );

      expect(text, 'turn on the lights');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://jarvis.test/transcribe');
      expect(request.headers['authorization'], 'Bearer jwt-1');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="file"'));
      expect(body, contains('filename="note.m4a"'));
      expect(body, contains('application/octet-stream'));
      expect(body, isNot(contains('name="model"')));
    });

    test('surfaces FastAPI detail for 400, 413, and 502', () async {
      Future<void> expectStatus(int status, String detail) async {
        final api = RemoteJarvisApi(
          auth: _TokenAuth('jwt-1'),
          endpoint: _Bases(['http://jarvis.test']),
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({'detail': detail}),
              status,
            );
          }),
        );
        expect(
          () => api.transcribeAudio(bytes: clip, filename: 'note.m4a'),
          throwsA(
            isA<JarvisRemoteException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.message, 'message', detail)
                .having(
                  (e) => e.kind,
                  'kind',
                  status == 401
                      ? RemoteFailureKind.auth
                      : RemoteFailureKind.other,
                ),
          ),
        );
      }

      await expectStatus(400, "Unsupported audio format '.bin'.");
      await expectStatus(413, 'Audio exceeds max size of 26214400 bytes.');
      await expectStatus(502, 'Failed to transcribe the audio file: down');
    });

    test('401 is an auth failure and is not sent without a token', () async {
      var calls = 0;
      final api = RemoteJarvisApi(
        auth: _TokenAuth(null),
        endpoint: _Bases(['http://jarvis.test']),
        httpClient: MockClient((request) async {
          calls++;
          return http.Response('nope', 500);
        }),
      );

      expect(
        () => api.transcribeAudio(bytes: clip, filename: 'note.m4a'),
        throwsA(
          isA<JarvisRemoteException>().having(
            (e) => e.kind,
            'kind',
            RemoteFailureKind.auth,
          ),
        ),
      );
      expect(calls, 0);

      final authed = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(['http://jarvis.test']),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Could not validate credentials'}),
            401,
          );
        }),
      );
      final error = await authed
          .transcribeAudio(bytes: clip, filename: 'note.m4a')
          .then<Object>((_) => 'ok', onError: (Object e) => e);
      expect(error, isA<JarvisRemoteException>());
      expect(
        describeTranscriptionError(error),
        'Remote authentication failed. Please log in again.',
      );
    });
  });

  group('on-device Whisper', () {
    test('posts whisper-1 to OpenAI and does not call Jarvis', () async {
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'text': 'lights on'}),
          200,
        );
      });
      final transcriber = PromptTranscriber(
        remote: RemoteAudioTranscriber(
          RemoteJarvisApi(
            auth: _TokenAuth('jwt-1'),
            endpoint: _Bases(['http://jarvis.test']),
            httpClient: mock,
          ),
        ),
        localForKey: (key) => OpenAiWhisperClient(
          apiKey: key,
          httpClient: mock,
        ),
      );

      final text = await transcriber.transcribe(
        bytes: clip,
        filename: 'jarvis-mic-9.m4a',
        context: const SpeechContext(
          mode: JarvisMode.local,
          offlineActive: false,
          openAiApiKey: 'sk-test',
        ),
      );

      expect(text, 'lights on');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.url.toString(), AppConfig.openAiAudioTranscriptionsUrl);
      expect(request.url.toString(), isNot(contains('/transcribe')));
      expect(request.headers['authorization'], 'Bearer sk-test');
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="model"'));
      expect(body, contains(AppConfig.whisperModel));
      expect(body, contains('name="file"'));
      expect(body, contains('filename="jarvis-mic-9.m4a"'));
      expect(body, isNot(contains('sk-test')));
    });

    test('maps OpenAI 401 through the settings message', () async {
      final client = OpenAiWhisperClient(
        apiKey: 'sk-bad',
        httpClient: MockClient((request) async {
          return http.Response('unauthorized', 401);
        }),
      );
      final error = await client
          .transcribe(bytes: clip, filename: 'clip.m4a')
          .then<Object>((_) => 'ok', onError: (Object e) => e);
      expect(error, isA<OpenAiException>());
      expect(
        describeTranscriptionError(error),
        'Invalid OpenAI API key. Open Settings and paste a valid key.',
      );
    });
  });

  group('prompt text', () {
    test('appends dictation without wiping a draft', () {
      expect(mergeDictationIntoPrompt('', '  hello  '), 'hello');
      expect(mergeDictationIntoPrompt('draft', 'hello'), 'draft hello');
      expect(mergeDictationIntoPrompt('draft ', 'hello'), 'draft hello');
      expect(mergeDictationIntoPrompt('draft\n', 'hello'), 'draft\nhello');
      expect(mergeDictationIntoPrompt('draft', '   '), 'draft');
    });

    test('formats the recording clock', () {
      expect(formatRecordingClock(Duration.zero), '00:00');
      expect(formatRecordingClock(const Duration(seconds: 65)), '01:05');
    });
  });
}
