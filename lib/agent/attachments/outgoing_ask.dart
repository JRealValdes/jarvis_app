import 'dart:convert';
import 'dart:typed_data';

import '../../config/app_config.dart';
import '../../domain/chat_image.dart';
import '../speech/transcription_errors.dart';
import 'pending_attachment.dart';

/// What the user sees on the bubble for one audio chip (not the transcript).
class AskBubbleMedia {
  const AskBubbleMedia.image({
    required this.bytes,
    required this.label,
  }) : isImage = true;

  const AskBubbleMedia.audio({required this.label})
      : isImage = false,
        bytes = null;

  final bool isImage;
  final Uint8List? bytes;
  final String label;
}

/// Model payload plus the bubble the user should see before history reloads.
class PreparedAsk {
  const PreparedAsk({
    required this.modelMessage,
    required this.visibleText,
    required this.images,
    required this.media,
  });

  /// `POST /ask` `message`. May be empty when [images] is not.
  /// Audio transcripts are included here and are not the composer text.
  final String modelMessage;

  /// Typed prompt only. Empty when the turn is attachments without text.
  final String visibleText;
  final List<ChatImage> images;
  final List<AskBubbleMedia> media;
}

/// Typed prompt plus hidden audio context. Does not include image bytes.
///
/// An empty result is valid when the turn has images and no text or audio.
String composeAskMessage({
  required String typed,
  required List<({String filename, String text})> transcripts,
}) {
  final prompt = typed.trim();
  final blocks = <String>[];
  for (final item in transcripts) {
    final text = item.text.trim();
    if (text.isEmpty) {
      throw SpeechTranscriptionException(
        'No speech detected in ${item.filename}.',
      );
    }
    blocks.add('[Audio context: ${item.filename}]\n$text');
  }
  if (prompt.isEmpty) return blocks.join('\n\n');
  if (blocks.isEmpty) return prompt;
  return '$prompt\n\n${blocks.join('\n\n')}';
}

/// UI history line matching Jarvis `GET /message-history` for image turns.
String historyUserContent({
  required String message,
  required int imageCount,
}) {
  if (imageCount <= 0) return message;
  final text = message.trim().isEmpty
      ? AppConfig.imageOnlyPrompt
      : message.trim();
  final markers = List.filled(
    imageCount,
    AppConfig.historyImageMarker,
  ).join('\n');
  return '$text\n$markers';
}

/// Transcribe each audio file, then build one ask payload.
///
/// Image bytes are base64-encoded here. Audio bytes are not sent on `/ask`.
Future<PreparedAsk> prepareOutgoingAsk({
  required String typed,
  required List<PendingAttachment> attachments,
  required Future<String> Function(PendingAttachment audio) transcribeAudio,
}) async {
  final transcripts = <({String filename, String text})>[];
  for (final attachment in attachments) {
    if (!attachment.isAudio) continue;
    final text = await transcribeAudio(attachment);
    transcripts.add((filename: attachment.filename, text: text));
  }
  final images = <ChatImage>[
    for (final attachment in attachments)
      if (attachment.isImage)
        ChatImage(
          mediaType: attachment.mediaType ?? 'image/jpeg',
          dataBase64: base64Encode(attachment.bytes),
        ),
  ];
  final media = <AskBubbleMedia>[
    for (final attachment in attachments)
      if (attachment.isImage)
        AskBubbleMedia.image(
          bytes: attachment.bytes,
          label: attachment.filename,
        )
      else
        AskBubbleMedia.audio(label: attachment.filename),
  ];
  return PreparedAsk(
    modelMessage: composeAskMessage(typed: typed, transcripts: transcripts),
    visibleText: typed.trim(),
    images: images,
    media: media,
  );
}
