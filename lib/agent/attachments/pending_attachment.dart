import 'dart:typed_data';

import '../../config/app_config.dart';
import '../speech/audio_payload.dart';
import '../speech/transcription_errors.dart';
import 'image_payload.dart';

enum AttachmentKind { image, audio }

/// One file waiting in the composer. Bytes stay on device until send.
class PendingAttachment {
  const PendingAttachment({
    required this.id,
    required this.kind,
    required this.filename,
    required this.bytes,
    required this.mediaType,
  });

  final String id;
  final AttachmentKind kind;
  final String filename;
  final Uint8List bytes;

  /// Set for images. Null for audio.
  final String? mediaType;

  bool get isImage => kind == AttachmentKind.image;
  bool get isAudio => kind == AttachmentKind.audio;
}

/// A file the platform picker returned. [sizeBytes] can exceed [bytes] when the
/// file was not read because it is already over the cap.
class PickedMedia {
  const PickedMedia({
    required this.filename,
    required this.bytes,
    required this.sizeBytes,
    this.mediaType,
  });

  final String filename;
  final Uint8List bytes;
  final int sizeBytes;
  final String? mediaType;
}

class AttachmentIntake {
  const AttachmentIntake({
    required this.accepted,
    required this.notices,
  });

  final List<PendingAttachment> accepted;
  final List<String> notices;
}

int countAttachments(List<PendingAttachment> items, AttachmentKind kind) {
  return items.where((item) => item.kind == kind).length;
}

/// Accept as many picked files as the remaining cap allows.
///
/// Invalid files are skipped with a notice. Extra files past the cap are not
/// added. [nextId] is called once per accepted item.
AttachmentIntake intakeAttachments({
  required List<PendingAttachment> existing,
  required AttachmentKind kind,
  required List<PickedMedia> picked,
  required String Function() nextId,
}) {
  final accepted = <PendingAttachment>[];
  final notices = <String>[];
  final cap = kind == AttachmentKind.image
      ? AppConfig.maxImagesPerMessage
      : AppConfig.maxAudioFilesPerMessage;
  var used = countAttachments(existing, kind);

  if (picked.isEmpty) {
    return const AttachmentIntake(accepted: [], notices: []);
  }
  if (used >= cap) {
    return AttachmentIntake(
      accepted: const [],
      notices: [_capMessage(kind)],
    );
  }

  var droppedForCap = false;
  for (final item in picked) {
    if (used >= cap) {
      droppedForCap = true;
      break;
    }
    try {
      final pending = _acceptOne(item, kind: kind, id: nextId());
      accepted.add(pending);
      used++;
    } on ImageAttachmentException catch (e) {
      notices.add(e.message);
    } on SpeechTranscriptionException catch (e) {
      notices.add(e.message);
    }
  }
  if (droppedForCap) {
    notices.add(
      kind == AttachmentKind.image
          ? 'Only ${AppConfig.maxImagesPerMessage} images can be attached. '
              'Extra files were not added.'
          : 'Only ${AppConfig.maxAudioFilesPerMessage} audio files can be attached. '
              'Extra files were not added.',
    );
  }
  return AttachmentIntake(accepted: accepted, notices: notices);
}

PendingAttachment _acceptOne(
  PickedMedia item, {
  required AttachmentKind kind,
  required String id,
}) {
  final filename = item.filename.trim().isEmpty ? 'attachment' : item.filename.trim();
  if (kind == AttachmentKind.audio) {
    validateAudioPayload(sizeBytes: item.sizeBytes, filename: filename);
    if (item.bytes.isEmpty) {
      throw const SpeechTranscriptionException('Could not read the selected file.');
    }
    return PendingAttachment(
      id: id,
      kind: kind,
      filename: filename,
      bytes: item.bytes,
      mediaType: null,
    );
  }
  final mediaType = validateImagePayload(
    sizeBytes: item.sizeBytes,
    filename: filename,
    mediaType: sniffImageMediaType(item.bytes) ?? item.mediaType,
  );
  if (item.bytes.isEmpty || item.bytes.length != item.sizeBytes) {
    throw const ImageAttachmentException('Could not read the selected file.');
  }
  return PendingAttachment(
    id: id,
    kind: kind,
    filename: filename,
    bytes: item.bytes,
    mediaType: mediaType,
  );
}

String _capMessage(AttachmentKind kind) {
  if (kind == AttachmentKind.image) {
    return 'At most ${AppConfig.maxImagesPerMessage} images are allowed per message.';
  }
  return 'At most ${AppConfig.maxAudioFilesPerMessage} audio files are allowed per message.';
}

/// Shown above the composer once a cap is reached. Null when there is still room.
String? attachmentLimitMessage(List<PendingAttachment> items) {
  final images = countAttachments(items, AttachmentKind.image);
  final audio = countAttachments(items, AttachmentKind.audio);
  final parts = <String>[];
  if (images >= AppConfig.maxImagesPerMessage) {
    parts.add('Image limit reached (${AppConfig.maxImagesPerMessage})');
  }
  if (audio >= AppConfig.maxAudioFilesPerMessage) {
    parts.add('Audio limit reached (${AppConfig.maxAudioFilesPerMessage})');
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
