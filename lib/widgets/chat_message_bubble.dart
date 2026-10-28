import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:jarvis_app/agent/chat_controller.dart';
import 'package:jarvis_app/widgets/assistant_markdown_styles.dart';

/// Chat bubble matching the existing app look.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.text,
    required this.isUser,
    this.media = const [],
    super.key,
  });

  final String text;
  final bool isUser;
  final List<ChatBubbleMedia> media;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Container(
        constraints: BoxConstraints(
          // Leave room for the opposing bubble alignment padding.
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: isUser
            ? _UserBubbleBody(text: text, media: media)
            : MarkdownBody(
                data: text,
                selectable: false,
                styleSheet: assistantMarkdownStyleSheet(context),
              ),
      ),
    );
  }
}

class _UserBubbleBody extends StatelessWidget {
  const _UserBubbleBody({required this.text, required this.media});

  final String text;
  final List<ChatBubbleMedia> media;

  @override
  Widget build(BuildContext context) {
    final showText = text.trim().isNotEmpty;
    if (media.isEmpty) return Text(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in media) ...[
          if (item.isImage && item.bytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  item.bytes!,
                  width: 160,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.audio_file, size: 18),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (showText) Text(text),
      ],
    );
  }
}
