import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/attachments/image_payload.dart';
import 'package:jarvis_app/agent/attachments/outgoing_ask.dart';
import 'package:jarvis_app/agent/attachments/pending_attachment.dart';
import 'package:jarvis_app/agent/attachments/vision_content.dart';
import 'package:jarvis_app/agent/openai/openai_client.dart';
import 'package:jarvis_app/agent/remote/auth_service.dart';
import 'package:jarvis_app/agent/remote/endpoint.dart';
import 'package:jarvis_app/agent/remote/remote_failure.dart';
import 'package:jarvis_app/agent/remote/remote_jarvis_api.dart';
import 'package:jarvis_app/agent/session/jarvis_session.dart';
import 'package:jarvis_app/agent/speech/transcription_errors.dart';
import 'package:jarvis_app/agent/tools/registry.dart';
import 'package:jarvis_app/config/app_config.dart';
import 'package:jarvis_app/domain/chat_image.dart';
import 'package:jarvis_app/domain/chat_state.dart';
import 'package:jarvis_app/domain/models/user_profile.dart';

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

void main() {
  Uint8List bytes(int n) => Uint8List.fromList(List<int>.filled(n, 7));

  PickedMedia imageFile(String name, int size, {Uint8List? data, String? type}) {
    final payload = data ?? bytes(size);
    return PickedMedia(
      filename: name,
      bytes: payload,
      sizeBytes: size,
      mediaType: type,
    );
  }

  group('intake caps', () {
    test('accepts up to 4 images and 2 audio files', () {
      var n = 0;
      final images = intakeAttachments(
        existing: const [],
        kind: AttachmentKind.image,
        picked: [
          for (var i = 0; i < 5; i++) imageFile('p$i.png', 4),
        ],
        nextId: () => 'i${n++}',
      );
      expect(images.accepted, hasLength(4));
      expect(images.notices.single, contains('Only 4 images'));

      final audio = intakeAttachments(
        existing: const [],
        kind: AttachmentKind.audio,
        picked: [
          for (final name in ['a.mp3', 'b.wav', 'c.m4a'])
            PickedMedia(filename: name, bytes: bytes(3), sizeBytes: 3),
        ],
        nextId: () => 'a${n++}',
      );
      expect(audio.accepted, hasLength(2));
      expect(audio.notices.single, contains('Only 2 audio'));
    });

    test('a full image cap explains itself and adds nothing', () {
      final existing = [
        for (var i = 0; i < 4; i++)
          PendingAttachment(
            id: 'e$i',
            kind: AttachmentKind.image,
            filename: 'e$i.png',
            bytes: bytes(2),
            mediaType: 'image/png',
          ),
      ];
      final intake = intakeAttachments(
        existing: existing,
        kind: AttachmentKind.image,
        picked: [imageFile('extra.png', 2)],
        nextId: () => 'nope',
      );
      expect(intake.accepted, isEmpty);
      expect(intake.notices.single, contains('At most 4 images'));
      expect(
        attachmentLimitMessage(existing),
        'Image limit reached (4)',
      );
    });

    test('rejects empty, oversized, and unsupported images', () {
      expect(
        () => validateImagePayload(sizeBytes: 0, filename: 'a.png'),
        throwsA(
          isA<ImageAttachmentException>().having(
            (e) => e.message,
            'message',
            'Image file is empty.',
          ),
        ),
      );
      expect(
        () => validateImagePayload(sizeBytes: 8, filename: 'a.png', maxBytes: 4),
        throwsA(
          isA<ImageAttachmentException>().having(
            (e) => e.message,
            'message',
            'Image exceeds max size of 4 bytes.',
          ),
        ),
      );
      expect(
        () => validateImagePayload(sizeBytes: 4, filename: 'a.bmp'),
        throwsA(
          isA<ImageAttachmentException>().having(
            (e) => e.message,
            'message',
            contains("Unsupported image file extension '.bmp'"),
          ),
        ),
      );
      expect(
        canonicalImageMediaType('image/jpg; charset=binary'),
        'image/jpeg',
      );
    });

    test('jpeg magic bytes win over a png filename', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);
      final intake = intakeAttachments(
        existing: const [],
        kind: AttachmentKind.image,
        picked: [
          PickedMedia(
            filename: 'shot.png',
            bytes: jpeg,
            sizeBytes: jpeg.length,
            mediaType: 'image/png',
          ),
        ],
        nextId: () => 'shot',
      );
      expect(intake.accepted.single.mediaType, 'image/jpeg');
    });
  });

  group('ask message', () {
    test('keeps the typed prompt and hides audio transcripts in the payload', () {
      expect(
        composeAskMessage(
          typed: 'Summarize this',
          transcripts: [
            (filename: 'notes.m4a', text: '  bring the suit  '),
            (filename: 'b.wav', text: 'and the car'),
          ],
        ),
        'Summarize this\n\n'
        '[Audio context: notes.m4a]\nbring the suit\n\n'
        '[Audio context: b.wav]\nand the car',
      );
      expect(
        composeAskMessage(typed: '  hi  ', transcripts: const []),
        'hi',
      );
      expect(
        composeAskMessage(
          typed: '   ',
          transcripts: [(filename: 'a.mp3', text: 'only audio')],
        ),
        '[Audio context: a.mp3]\nonly audio',
      );
    });

    test('blank transcript fails before send', () {
      expect(
        () => composeAskMessage(
          typed: 'hi',
          transcripts: [(filename: 'a.mp3', text: '  ')],
        ),
        throwsA(isA<SpeechTranscriptionException>()),
      );
    });

    test('history matches the server image marker', () {
      expect(
        historyUserContent(message: 'look', imageCount: 2),
        'look\n[Image attached]\n[Image attached]',
      );
      expect(
        historyUserContent(message: '', imageCount: 1),
        '${AppConfig.imageOnlyPrompt}\n[Image attached]',
      );
      expect(historyUserContent(message: 'hi', imageCount: 0), 'hi');
    });

    test('prepare encodes images and calls transcribe once per audio file', () async {
      final calls = <String>[];
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
      final prepared = await prepareOutgoingAsk(
        typed: 'What is this?',
        attachments: [
          PendingAttachment(
            id: '1',
            kind: AttachmentKind.image,
            filename: 'pic.png',
            bytes: png,
            mediaType: 'image/png',
          ),
          PendingAttachment(
            id: '2',
            kind: AttachmentKind.audio,
            filename: 'note.m4a',
            bytes: bytes(4),
            mediaType: null,
          ),
        ],
        transcribeAudio: (audio) async {
          calls.add(audio.filename);
          return 'lights on';
        },
      );
      expect(calls, ['note.m4a']);
      expect(prepared.visibleText, 'What is this?');
      expect(prepared.modelMessage, contains('[Audio context: note.m4a]'));
      expect(prepared.modelMessage, contains('lights on'));
      expect(prepared.modelMessage, isNot(contains('base64')));
      expect(prepared.images.single.mediaType, 'image/png');
      expect(prepared.images.single.dataBase64, base64Encode(png));
      expect(prepared.media, hasLength(2));
      expect(prepared.media.first.isImage, isTrue);
      expect(prepared.media.last.isImage, isFalse);
    });
  });

  group('local vision messages', () {
    const image = ChatImage(mediaType: 'image/jpeg', dataBase64: 'abc');

    test('blank prompt becomes the image-only line plus data urls', () {
      final content = userMessageContent('', [image]);
      expect(content, isA<List>());
      final blocks = content as List;
      expect(blocks.first['text'], AppConfig.imageOnlyPrompt);
      expect(
        blocks.last['image_url']['url'],
        'data:image/jpeg;base64,abc',
      );
      expect(userMessageContent('hello', const []), 'hello');
    });

    test('older photos are omitted and the latest image bytes stay', () {
      final prepared = prepareMessagesForVision([
        {
          'role': 'user',
          'content': userMessageContent('first', [image]),
        },
        {'role': 'assistant', 'content': 'ok'},
        {
          'role': 'user',
          'content': userMessageContent('second', [
            const ChatImage(mediaType: 'image/png', dataBase64: 'NEW'),
          ]),
        },
      ]);
      expect(prepared[0]['content'], isA<String>());
      expect(prepared[0]['content'], contains(AppConfig.omittedImageNote));
      expect(prepared[0]['content'], contains('first'));
      expect(prepared[0]['content'], isNot(contains('abc')));
      final latest = prepared[2]['content'] as List;
      expect(jsonEncode(latest), contains('NEW'));
      expect(jsonEncode(latest), isNot(contains('abc')));
    });

    test('gpt-3.5 does not call OpenAI when images are attached', () async {
      var calls = 0;
      final session = JarvisSession(
        threadId: 'local',
        profile: const UserProfile(jarvisName: 'Tony', isFemale: false),
        openAi: OpenAiClient(
          apiKey: 'k',
          httpClient: MockClient((request) async {
            calls++;
            return http.Response('nope', 500);
          }),
        ),
        tools: builtInTools(),
        model: 'gpt-3.5-turbo',
        initialState: ChatState.initialized,
      );
      final reply = await session.ask('look', images: const [image]);
      expect(calls, 0);
      expect(reply.single, contains('does not support images'));
      expect(reply.single, contains('gpt-4o-mini'));
    });

    test('a follow-up sends only the latest image to OpenAI', () async {
      final bodies = <Map<String, dynamic>>[];
      final session = JarvisSession(
        threadId: 'local',
        profile: const UserProfile(jarvisName: 'Tony', isFemale: false),
        openAi: OpenAiClient(
          apiKey: 'k',
          httpClient: MockClient((request) async {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'role': 'assistant',
                      'content': 'I see it, sir.',
                    },
                  }
                ],
              }),
              200,
            );
          }),
        ),
        tools: builtInTools(),
        model: 'gpt-4o-mini',
        initialState: ChatState.initialized,
        llmMessages: [
          {
            'role': 'user',
            'content': userMessageContent('old photo', [
              const ChatImage(mediaType: 'image/png', dataBase64: 'OLD'),
            ]),
          },
          {'role': 'assistant', 'content': 'noted'},
        ],
      );

      final reply = await session.ask(
        'and this?',
        images: const [ChatImage(mediaType: 'image/jpeg', dataBase64: 'NEW')],
      );
      expect(reply.single, 'I see it, sir.');
      expect(bodies, hasLength(1));
      expect(bodies.single['model'], 'gpt-4o-mini');
      final messages = bodies.single['messages'] as List;
      final encoded = jsonEncode(messages);
      expect(encoded, contains('NEW'));
      expect(encoded, isNot(contains('OLD')));
      expect(encoded, contains(AppConfig.omittedImageNote));
      final saved = jsonEncode(session.llmMessages);
      expect(saved, contains('NEW'));
      expect(saved, isNot(contains('OLD')));
    });
  });

  group('POST /ask images', () {
    test('sends base64 images and allows an empty message', () async {
      final requests = <http.Request>[];
      final api = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(['http://jarvis.test']),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'response': ['Welcome, sir.', 'A workshop.'],
            }),
            200,
          );
        }),
      );

      final replies = await api.ask(
        '',
        modelName: 'GPT_4O_MINI',
        images: const [
          ChatImage(mediaType: 'image/jpeg', dataBase64: 'abc'),
        ],
      );

      expect(replies, ['Welcome, sir.', 'A workshop.']);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requests.single.url.toString(), 'http://jarvis.test/ask');
      expect(requests.single.headers['authorization'], 'Bearer jwt-1');
      expect(body['message'], '');
      expect(body['model_name'], 'GPT_4O_MINI');
      expect(body['images'], [
        {'media_type': 'image/jpeg', 'data_base64': 'abc'},
      ]);
    });

    test('text asks omit the images field', () async {
      final requests = <http.Request>[];
      final api = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(['http://jarvis.test']),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'response': ['ok']}), 200);
        }),
      );
      await api.ask('hello', modelName: 'GPT_4O_MINI');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body.containsKey('images'), isFalse);
      expect(body['message'], 'hello');
    });

    test('surfaces image validation detail without failing over', () async {
      final api = RemoteJarvisApi(
        auth: _TokenAuth('jwt-1'),
        endpoint: _Bases(['http://jarvis.test']),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'detail':
                  'The selected model does not support images. Use GPT_4O_MINI.',
            }),
            400,
          );
        }),
      );
      expect(
        () => api.ask(
          'look',
          modelName: 'GPT_3_5',
          images: const [
            ChatImage(mediaType: 'image/png', dataBase64: 'abc'),
          ],
        ),
        throwsA(
          isA<JarvisRemoteException>()
              .having((e) => e.statusCode, 'status', 400)
              .having(
                (e) => e.message,
                'message',
                'The selected model does not support images. Use GPT_4O_MINI.',
              )
              .having((e) => e.kind, 'kind', RemoteFailureKind.other),
        ),
      );
    });
  });
}
