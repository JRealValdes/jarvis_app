import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/speech/audio_transcriber.dart';
import 'package:jarvis_app/agent/speech/composer_mic_controller.dart';
import 'package:jarvis_app/agent/speech/mic_session.dart';
import 'package:jarvis_app/agent/speech/prompt_transcriber.dart';
import 'package:jarvis_app/agent/speech/speech_route.dart';
import 'package:jarvis_app/agent/speech/transcription_errors.dart';
import 'package:jarvis_app/domain/models/jarvis_mode.dart';
import 'package:jarvis_app/widgets/chat_composer.dart';

class _FakeMic implements MicSession {
  bool allow = true;
  bool dropClipOnStop = false;
  int startCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;
  String? startedPath;
  List<int> payload = const [1, 2, 3, 4];

  @override
  Future<bool> hasPermission() async => allow;

  @override
  Future<void> start({required String path}) async {
    startCount++;
    startedPath = path;
    await File(path).writeAsBytes(payload);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    if (dropClipOnStop && startedPath != null) {
      final file = File(startedPath!);
      if (await file.exists()) await file.delete();
      return null;
    }
    return startedPath;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

class _Scripted implements AudioTranscriber {
  _Scripted(this.text);

  final String text;
  bool fail = false;
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
    if (fail) {
      throw const SpeechTranscriptionException('Whisper down');
    }
    return text;
  }
}

void main() {
  late Directory temp;
  late _FakeMic mic;
  late _Scripted remote;
  late ComposerMicController controller;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('jarvis-mic-test-');
    mic = _FakeMic();
    remote = _Scripted('lights on');
    controller = ComposerMicController(
      session: mic,
      transcriber: PromptTranscriber(
        remote: remote,
        localForKey: (_) => throw StateError('local whisper must not run'),
      ),
      readContext: () async => const SpeechContext(
        mode: JarvisMode.remote,
        offlineActive: false,
        openAiApiKey: null,
      ),
      newClipPath: () async =>
          '${temp.path}${Platform.pathSeparator}jarvis-mic-1.m4a',
    );
  });

  tearDown(() async {
    await controller.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('permission denial does not start a clip', () async {
    mic.allow = false;
    await expectLater(
      controller.start(),
      throwsA(isA<MicPermissionDeniedException>()),
    );
    expect(mic.startCount, 0);
    expect(controller.phase, ComposerMicPhase.idle);
    expect(
      describeTranscriptionError(const MicPermissionDeniedException()),
      contains('system settings'),
    );
  });

  test('pause and resume keep the same recording', () async {
    await controller.start();
    await controller.pause();
    await controller.resume();
    expect(mic.startCount, 1);
    expect(mic.pauseCount, 1);
    expect(mic.resumeCount, 1);
    expect(controller.phase, ComposerMicPhase.recording);
    expect(mic.startedPath, endsWith('jarvis-mic-1.m4a'));
  });

  test('cancel discards the temp clip', () async {
    await controller.start();
    final path = mic.startedPath!;
    expect(File(path).existsSync(), isTrue);
    await controller.cancel();
    expect(mic.cancelCount, 1);
    expect(File(path).existsSync(), isFalse);
    expect(controller.phase, ComposerMicPhase.idle);
    expect(remote.calls, 0);
  });

  test('finish transcribes then deletes the clip', () async {
    await controller.start();
    final path = mic.startedPath!;
    final text = await controller.finish();
    expect(text, 'lights on');
    expect(remote.calls, 1);
    expect(remote.lastBytes, mic.payload);
    expect(remote.lastFilename, 'jarvis-mic-1.m4a');
    expect(File(path).existsSync(), isFalse);
    expect(controller.phase, ComposerMicPhase.idle);
  });

  test('a failed transcription still deletes the clip', () async {
    remote.fail = true;
    await controller.start();
    final path = mic.startedPath!;
    await expectLater(
      controller.finish(),
      throwsA(
        isA<SpeechTranscriptionException>().having(
          (e) => e.message,
          'message',
          'Whisper down',
        ),
      ),
    );
    expect(File(path).existsSync(), isFalse);
    expect(controller.phase, ComposerMicPhase.idle);
  });

  test('an empty capture does not call the transcriber', () async {
    mic.dropClipOnStop = true;
    await controller.start();
    await expectLater(
      controller.finish(),
      throwsA(
        isA<SpeechTranscriptionException>().having(
          (e) => e.message,
          'message',
          'Recording was empty.',
        ),
      ),
    );
    expect(remote.calls, 0);
    expect(controller.phase, ComposerMicPhase.idle);
  });

  test('a second start is ignored while recording', () async {
    await controller.start();
    await controller.start();
    expect(mic.startCount, 1);
  });

  testWidgets('idle composer shows the field, mic, and send', (tester) async {
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _host(
        ChatComposer(
          controller: input,
          focusNode: focus,
          phase: ComposerMicPhase.idle,
          elapsed: Duration.zero,
          inputEnabled: true,
          onSend: () {},
          onMic: () {},
          onCancel: () {},
          onTogglePause: () {},
          onFinish: () {},
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('recording replaces the field with cancel, pause, and finish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final input = TextEditingController(text: 'draft');
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    var finished = false;

    await tester.pumpWidget(
      _host(
        ChatComposer(
          controller: input,
          focusNode: focus,
          phase: ComposerMicPhase.recording,
          elapsed: const Duration(seconds: 65),
          inputEnabled: true,
          onSend: () {},
          onMic: () {},
          onCancel: () {},
          onTogglePause: () {},
          onFinish: () => finished = true,
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Recording 01:05'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Finish'));
    expect(finished, isTrue);
  });

  testWidgets('paused shows resume and transcribing hides the controls',
      (tester) async {
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _host(
        ChatComposer(
          controller: input,
          focusNode: focus,
          phase: ComposerMicPhase.paused,
          elapsed: const Duration(seconds: 5),
          inputEnabled: true,
          onSend: () {},
          onMic: () {},
          onCancel: () {},
          onTogglePause: () {},
          onFinish: () {},
        ),
      ),
    );
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Paused 00:05'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        ChatComposer(
          controller: input,
          focusNode: focus,
          phase: ComposerMicPhase.transcribing,
          elapsed: Duration.zero,
          inputEnabled: false,
          onSend: null,
          onMic: null,
          onCancel: null,
          onTogglePause: null,
          onFinish: null,
        ),
      ),
    );
    expect(find.text('Transcribing…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('mic stays disabled when dictation is unavailable', (tester) async {
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _host(
        ChatComposer(
          controller: input,
          focusNode: focus,
          phase: ComposerMicPhase.idle,
          elapsed: Duration.zero,
          inputEnabled: false,
          onSend: null,
          onMic: null,
          onCancel: null,
          onTogglePause: null,
          onFinish: null,
        ),
      ),
    );

    final micButton = tester.widget<IconButton>(find.byKey(composerMicKey));
    expect(micButton.onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
