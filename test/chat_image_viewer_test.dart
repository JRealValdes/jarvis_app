import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/chat_controller.dart';
import 'package:jarvis_app/widgets/assistant_markdown_image.dart';
import 'package:jarvis_app/widgets/chat_image_viewer.dart';
import 'package:jarvis_app/widgets/chat_message_bubble.dart';

/// Minimal valid 1x1 PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB4, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  const imageUrl = 'http://192.168.1.10:8000/images/deadbeef';

  Widget host(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('download control invokes the save callback', (tester) async {
    String? savedUrl;
    await tester.pumpWidget(
      host(
        ChatImageViewerPage(
          imageUrl: imageUrl,
          imageProvider: MemoryImage(_png),
          onSave: (url) async {
            savedUrl = url;
            return null;
          },
        ),
      ),
    );

    expect(find.byKey(ChatImageViewerPage.downloadKey), findsOneWidget);
    await tester.tap(find.byKey(ChatImageViewerPage.downloadKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(savedUrl, imageUrl);
    expect(find.text('Image saved to the gallery.'), findsOneWidget);
  });

  testWidgets('tap on assistant markdown image opens the viewer', (tester) async {
    var saveCalls = 0;
    await tester.pumpWidget(
      host(
        ChatMessageBubble(
          text: 'Here: ![cat](/images/deadbeef)',
          isUser: false,
          apiBaseUrl: 'http://192.168.1.10:8000',
          saveImage: (url) async {
            saveCalls++;
            return null;
          },
          imageProviderForUrl: (_) => MemoryImage(_png),
        ),
      ),
    );
    await tester.pump();

    final tapFinder = find.byKey(
      const Key('${AssistantMarkdownImage.tapKeyPrefix}$imageUrl'),
    );
    expect(tapFinder, findsOneWidget);

    await tester.tap(tapFinder);
    await tester.pumpAndSettle();

    expect(find.byType(ChatImageViewerPage), findsOneWidget);
    expect(find.byKey(ChatImageViewerPage.downloadKey), findsOneWidget);

    await tester.tap(find.byKey(ChatImageViewerPage.downloadKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(saveCalls, 1);
  });

  testWidgets('user-bubble attachment thumbnails stay Image.memory', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ChatMessageBubble(
          text: 'What is this?',
          isUser: true,
          media: [
            ChatBubbleMedia.image(bytes: _png, label: 'shot.png'),
          ],
          apiBaseUrl: 'http://192.168.1.10:8000',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AssistantMarkdownImage), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
