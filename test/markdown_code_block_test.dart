import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/widgets/chat_message_bubble.dart';
import 'package:jarvis_app/widgets/markdown_code_block.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  group('normalizeFenceCode', () {
    test('strips a single trailing newline', () {
      expect(normalizeFenceCode('Hi\n'), 'Hi');
      expect(normalizeFenceCode('Hi\n\n'), 'Hi\n');
      expect(normalizeFenceCode('Hi'), 'Hi');
    });
  });

  group('fenceLanguageFromPreElement', () {
    test('reads language-text from nested code class', () {
      final pre = md.Element('pre', [
        md.Element('code', [md.Text('Hi there')])
          ..attributes['class'] = 'language-text',
      ]);

      expect(fenceLanguageFromPreElement(pre), proposedReplyFenceLanguage);
    });

    test('reads other fence languages', () {
      final pre = md.Element('pre', [
        md.Element('code', [md.Text('Get-ChildItem')])
          ..attributes['class'] = 'language-powershell',
      ]);

      expect(fenceLanguageFromPreElement(pre), 'powershell');
    });

    test('returns null when class is missing', () {
      final pre = md.Element('pre', [
        md.Element('code', [md.Text('plain')]),
      ]);

      expect(fenceLanguageFromPreElement(pre), isNull);
    });
  });

  group('MarkdownCodeBlock in chat', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      );
    }

    testWidgets('shows Copy on fenced blocks and copies fence body only', (
      tester,
    ) async {
      const draft = '''Hi Name,

Thanks for reaching out about the role.''';
      const sample = '''
Here is a draft reply:

```text
$draft
```

Would you like to adjust anything?
''';
      final copied = <String>[];

      await tester.pumpWidget(
        wrap(
          ChatMessageBubble(
            text: sample,
            isUser: false,
            copyToClipboard: (text) async => copied.add(text),
          ),
        ),
      );

      expect(find.byType(MarkdownCodeBlock), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.textContaining('Here is a draft reply'), findsWidgets);
      expect(
        find.textContaining('Would you like to adjust anything'),
        findsWidgets,
      );

      final block = tester.widget<MarkdownCodeBlock>(
        find.byType(MarkdownCodeBlock),
      );
      await tester.tap(find.byKey(block.copyButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(copied, hasLength(1));
      expect(copied.single, draft);
      expect(find.text('Copied'), findsWidgets);
    });

    testWidgets('Copy works for non-text fence languages', (tester) async {
      const sample = '''
Run this:

```powershell
Get-ChildItem
```
''';
      final copied = <String>[];

      await tester.pumpWidget(
        wrap(
          ChatMessageBubble(
            text: sample,
            isUser: false,
            copyToClipboard: (text) async => copied.add(text),
          ),
        ),
      );

      final block = tester.widget<MarkdownCodeBlock>(
        find.byType(MarkdownCodeBlock),
      );
      expect(block.language, 'powershell');

      await tester.tap(find.byKey(block.copyButtonKey));
      await tester.pump();

      expect(copied, ['Get-ChildItem']);
    });

    testWidgets('shows error SnackBar when clipboard write fails', (
      tester,
    ) async {
      const sample = '''
```text
body
```
''';

      await tester.pumpWidget(
        wrap(
          ChatMessageBubble(
            text: sample,
            isUser: false,
            copyToClipboard: (_) async => throw StateError('denied'),
          ),
        ),
      );

      final block = tester.widget<MarkdownCodeBlock>(
        find.byType(MarkdownCodeBlock),
      );
      await tester.tap(find.byKey(block.copyButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Could not copy to clipboard'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('user bubbles do not get code-block Copy controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ChatMessageBubble(
            text: '''
```text
should stay plain
```
''',
            isUser: true,
          ),
        ),
      );

      expect(find.byType(MarkdownCodeBlock), findsNothing);
      expect(find.text('Copy'), findsNothing);
    });
  });
}
