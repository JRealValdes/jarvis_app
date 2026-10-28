import '../../config/app_config.dart';
import '../../domain/chat_image.dart';

/// Local / offline OpenAI content. Mirrors Jarvis `build_human_message`.
///
/// Blank text with images becomes [AppConfig.imageOnlyPrompt]. No images
/// keeps the prompt as a plain string so older turns stay unchanged.
Object userMessageContent(String prompt, List<ChatImage> images) {
  if (images.isEmpty) return prompt;
  final text = prompt.trim().isEmpty ? AppConfig.imageOnlyPrompt : prompt.trim();
  return <Map<String, dynamic>>[
    {'type': 'text', 'text': text},
    for (final image in images)
      {
        'type': 'image_url',
        'image_url': {
          'url': 'data:${image.mediaType};base64,${image.dataBase64}',
        },
      },
  ];
}

/// gpt-3.5-turbo cannot take image parts. Other configured ids are vision models.
bool openAiModelSupportsImages(String modelName) {
  return AppConfig.resolveOpenAiModelId(modelName) != 'gpt-3.5-turbo';
}

/// Plain-text rendering of a user `content` value (string or content blocks).
String humanContentForHistory(Object? content) {
  if (content is String) return content;
  if (content is! List) return content?.toString() ?? '';
  final parts = <String>[];
  for (final block in content) {
    if (block is String) {
      if (block.trim().isNotEmpty) parts.add(block);
      continue;
    }
    final map = _asMap(block);
    if (map == null) continue;
    if (map['type'] == 'text') {
      final text = map['text']?.toString().trim() ?? '';
      if (text.isNotEmpty) parts.add(text);
    } else if (map['type'] == 'image_url') {
      parts.add(AppConfig.historyImageMarker);
    }
  }
  return parts.join('\n');
}

/// Keep image bytes only on the latest user message that has them.
///
/// Older image turns stay in the thread as text plus [AppConfig.omittedImageNote].
List<Map<String, dynamic>> prepareMessagesForVision(
  List<Map<String, dynamic>> messages,
) {
  int? lastWithImages;
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    if (message['role'] == 'user' && _hasImageBlocks(message['content'])) {
      lastWithImages = i;
    }
  }
  if (lastWithImages == null) return messages;

  final prepared = <Map<String, dynamic>>[];
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final strip = i != lastWithImages &&
        message['role'] == 'user' &&
        _hasImageBlocks(message['content']);
    if (!strip) {
      prepared.add(message);
      continue;
    }
    prepared.add({
      ...message,
      'content': _withoutImages(message['content']),
    });
  }
  return prepared;
}

bool _hasImageBlocks(Object? content) {
  if (content is! List) return false;
  for (final block in content) {
    final map = _asMap(block);
    if (map != null && map['type'] == 'image_url') return true;
  }
  return false;
}

String _withoutImages(Object? content) {
  final text = humanContentForHistory(content);
  final lines = <String>[
    for (final line in text.split('\n'))
      if (line != AppConfig.historyImageMarker && line.trim().isNotEmpty) line,
  ];
  if (lines.isEmpty) return AppConfig.omittedImageNote;
  return '${lines.join('\n')}\n${AppConfig.omittedImageNote}';
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
