import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Chat bubble matching the existing app look.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.text,
    required this.isUser,
    super.key,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: isUser
            ? Text(text)
            : MarkdownBody(
                data: text,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium,
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                  h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}
