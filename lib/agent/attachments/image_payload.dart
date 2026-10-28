import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../config/app_config.dart';

/// Types Jarvis accepts on `POST /ask` images. `image/jpg` is stored as jpeg.
const supportedImageMediaTypes = <String>[
  'image/gif',
  'image/jpeg',
  'image/png',
  'image/webp',
];

const imageExtensionMediaTypes = <String, String>{
  '.gif': 'image/gif',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

/// File extensions for the image file picker (no leading dot).
const imageFilePickerExtensions = <String>[
  'gif',
  'jpeg',
  'jpg',
  'png',
  'webp',
];

class ImageAttachmentException implements Exception {
  const ImageAttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `image/jpg` and parameters (`image/jpeg; charset=...`) collapse to a canonical type.
String canonicalImageMediaType(String mediaType) {
  final media = mediaType.split(';').first.trim().toLowerCase();
  if (media == 'image/jpg') return 'image/jpeg';
  return media;
}

/// Media type from a filename. Throws when the extension is not a vision type.
String mediaTypeForImageFilename(String filename) {
  final ext = p.extension(p.basename(filename)).toLowerCase();
  final media = imageExtensionMediaTypes[ext];
  if (media == null) {
    final shown = ext.isEmpty ? '(none)' : ext;
    throw ImageAttachmentException(
      "Unsupported image file extension '$shown'.",
    );
  }
  return media;
}

/// Magic-byte type when the filename still says png/heic after camera compression.
String? sniffImageMediaType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

/// Reject empty, oversized, or unsupported images before any network call.
String validateImagePayload({
  required int sizeBytes,
  required String filename,
  String? mediaType,
  int maxBytes = AppConfig.maxImageBytes,
}) {
  final declared = mediaType == null || mediaType.trim().isEmpty
      ? mediaTypeForImageFilename(filename)
      : canonicalImageMediaType(mediaType);
  if (!supportedImageMediaTypes.contains(declared)) {
    final allowed = supportedImageMediaTypes.join(', ');
    final shown = declared.isEmpty ? '(none)' : declared;
    throw ImageAttachmentException(
      "Unsupported image type '$shown'. Allowed: $allowed.",
    );
  }
  if (sizeBytes <= 0) {
    throw const ImageAttachmentException('Image file is empty.');
  }
  if (sizeBytes > maxBytes) {
    throw ImageAttachmentException(
      'Image exceeds max size of $maxBytes bytes.',
    );
  }
  return declared;
}
