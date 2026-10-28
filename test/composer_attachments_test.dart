import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/attachments/pending_attachment.dart';
import 'package:jarvis_app/agent/chat_controller.dart';
import 'package:jarvis_app/agent/speech/composer_mic_controller.dart';
import 'package:jarvis_app/widgets/attachment_sheets.dart';
import 'package:jarvis_app/widgets/chat_composer.dart';
import 'package:jarvis_app/widgets/chat_message_bubble.dart';

void main() {
  final png = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );

  Widget host(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('pending chips show a thumbnail and an audio name, and remove', (
    tester,
  ) async {
    final attachments = [
      PendingAttachment(
        id: 'img',
        kind: AttachmentKind.image,
        filename: 'workshop.png',
        bytes: png,
        mediaType: 'image/png',
      ),
      PendingAttachment(
        id: 'aud',
        kind: AttachmentKind.audio,
        filename: 'notes.m4a',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        mediaType: null,
      ),
    ];
    String? removed;
    await tester.pumpWidget(
      host(
        ChatComposer(
          controller: TextEditingController(),
          focusNode: FocusNode(),
          phase: ComposerMicPhase.idle,
          elapsed: Duration.zero,
          inputEnabled: true,
          attachments: attachments,
          limitMessage: 'Image limit reached (4)',
          onSend: () {},
          onMic: () {},
          onAttach: () {},
          onCamera: () {},
          onRemoveAttachment: (id) => removed = id,
          onCancel: () {},
          onTogglePause: () {},
          onFinish: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    expect(find.text('workshop.png'), findsOneWidget);
    expect(find.text('notes.m4a'), findsOneWidget);
    expect(find.text('Image limit reached (4)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attachment_remove_aud')));
    expect(removed, 'aud');
  });

  testWidgets('paperclip sheet offers image and audio, and blocks a full cap', (
    tester,
  ) async {
    AttachKind? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                picked = await showAttachKindSheet(
                  context,
                  imagesAtLimit: true,
                  audioAtLimit: false,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Limit reached (4)'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);

    await tester.tap(find.byKey(attachImageChoiceKey));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Attach'), findsOneWidget);

    await tester.tap(find.byKey(attachAudioChoiceKey));
    await tester.pumpAndSettle();
    expect(picked, AttachKind.audio);
  });

  testWidgets('image source sheet offers gallery and files', (tester) async {
    ImagePickSource? source;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                source = await showImageSourceSheet(context);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    await tester.tap(find.byKey(imageFilesChoiceKey));
    await tester.pumpAndSettle();
    expect(source, ImagePickSource.files);
  });

  testWidgets('camera confirm returns use or retake', (tester) async {
    CameraConfirmAction? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                action = await showCameraConfirmDialog(context, png);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Use this photo?'), findsOneWidget);
    await tester.tap(find.byKey(cameraRetakeKey));
    await tester.pumpAndSettle();
    expect(action, CameraConfirmAction.retake);
  });

  testWidgets('user bubble shows the photo and audio name, not a transcript', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ChatMessageBubble(
          text: 'What is this?',
          isUser: true,
          media: [
            ChatBubbleMedia.image(bytes: png, label: 'workshop.png'),
            const ChatBubbleMedia.audio(label: 'notes.m4a'),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('What is this?'), findsOneWidget);
    expect(find.text('notes.m4a'), findsOneWidget);
    expect(find.byIcon(Icons.audio_file), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
