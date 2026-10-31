import 'package:flutter/material.dart';

import 'chat_image_viewer.dart';

/// Tappable inline image in an assistant markdown reply.
class AssistantMarkdownImage extends StatelessWidget {
  const AssistantMarkdownImage({
    required this.imageUrl,
    required this.onSave,
    this.alt,
    this.width,
    this.height,
    this.imageProvider,
    super.key,
  });

  static const tapKeyPrefix = 'assistant_markdown_image_';

  final String imageUrl;
  final Future<String?> Function(String url) onSave;
  final String? alt;
  final double? width;
  final double? height;
  final ImageProvider? imageProvider;

  Key get tapKey => Key('$tapKeyPrefix$imageUrl');

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider ?? NetworkImage(imageUrl);
    return GestureDetector(
      key: tapKey,
      onTap: () {
        openChatImageViewer(
          context,
          imageUrl: imageUrl,
          onSave: onSave,
          imageProvider: imageProvider,
        );
      },
      child: Semantics(
        button: true,
        label: alt?.isNotEmpty == true ? alt! : 'Open image',
        child: Image(
          image: provider,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_outlined,
            size: 48,
          ),
        ),
      ),
    );
  }
}
