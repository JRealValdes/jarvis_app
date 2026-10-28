import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/widgets/chat_message_bubble.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  testWidgets('user bubble stays plain text (no MarkdownBody)', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ChatMessageBubble(
          text: '**bold** and a `code` span',
          isUser: true,
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('**bold** and a `code` span'), findsOneWidget);
  });

  testWidgets('assistant short reply stays readable plain prose', (tester) async {
    const sample = 'The answer, Sir, is 4.';
    await tester.pumpWidget(
      wrap(const ChatMessageBubble(text: sample, isUser: false)),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('The answer, Sir, is 4.'), findsWidgets);
  });

  testWidgets('assistant nested / ordered list renders', (tester) async {
    const sample = '''
1. **Use a Descriptive Subject Line**: Keep it short.
2. **Be Concise and Direct**: Lead with the ask.
3. **Use Bullet Points or Lists**:
   - First detail
   - Second detail
''';
    await tester.pumpWidget(
      wrap(const ChatMessageBubble(text: sample, isUser: false)),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Use a Descriptive Subject Line'), findsWidgets);
    expect(find.textContaining('First detail'), findsWidgets);
  });

  testWidgets('assistant GFM table renders', (tester) async {
    const sample = '''
| Criteria | Python | Rust |
|----------|--------|------|
| **Ease of Use** | High | Moderate |
| **Performance** | Slower | High |
''';
    await tester.pumpWidget(
      wrap(const ChatMessageBubble(text: sample, isUser: false)),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('Python'), findsWidgets);
    expect(find.textContaining('Performance'), findsWidgets);
  });

  testWidgets('assistant fenced code block renders', (tester) async {
    const sample = '''
Run this:

```powershell
Get-ChildItem
```
''';
    await tester.pumpWidget(
      wrap(const ChatMessageBubble(text: sample, isUser: false)),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Get-ChildItem'), findsWidgets);
  });

  testWidgets('assistant heading hierarchy renders', (tester) async {
    const sample = '''
## Options
### Fast path
Do the quick thing.
''';
    await tester.pumpWidget(
      wrap(const ChatMessageBubble(text: sample, isUser: false)),
    );

    expect(find.textContaining('Options'), findsWidgets);
    expect(find.textContaining('Fast path'), findsWidgets);
  });
}
