import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../config/app_config.dart';
import '../speech/audio_payload.dart';
import 'image_payload.dart';
import 'pending_attachment.dart';

/// Gallery, camera, and file pickers. Callers enforce the per-message caps.
class DeviceAttachmentPicker {
  DeviceAttachmentPicker({ImagePicker? imagePicker})
      : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  static const double _edge = 2048;
  static const int _jpegQuality = 85;

  Future<List<PickedMedia>> pickGalleryImages({required int limit}) async {
    if (limit < 1) return const [];
    final files = await _images.pickMultiImage(
      maxWidth: _edge,
      maxHeight: _edge,
      imageQuality: _jpegQuality,
      limit: limit,
      requestFullMetadata: false,
    );
    final picked = <PickedMedia>[];
    for (final file in files) {
      picked.add(await _fromXFile(file));
    }
    return picked;
  }

  Future<List<PickedMedia>> pickImageFiles() {
    return _pickFiles(
      extensions: imageFilePickerExtensions,
      maxRead: AppConfig.maxImageBytes,
      image: true,
    );
  }

  Future<List<PickedMedia>> pickAudioFiles() {
    return _pickFiles(
      extensions: [
        for (final ext in supportedAudioExtensions) ext.substring(1),
      ],
      maxRead: AppConfig.maxAudioUploadBytes,
      image: false,
    );
  }

  Future<PickedMedia?> capturePhoto() async {
    final file = await _images.pickImage(
      source: ImageSource.camera,
      maxWidth: _edge,
      maxHeight: _edge,
      imageQuality: _jpegQuality,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return _fromXFile(file);
  }

  /// Photo the camera intent returned after Android recreated the activity.
  Future<PickedMedia?> recoverLostCapture() async {
    final lost = await _images.retrieveLostData();
    if (lost.isEmpty || lost.file == null) return null;
    if (lost.type != RetrieveType.image) return null;
    return _fromXFile(lost.file!);
  }

  Future<PickedMedia> _fromXFile(XFile file) async {
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final rawName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : p.basename(file.path);
    final filename = rawName.isEmpty ? 'photo.jpg' : rawName;
    return PickedMedia(
      filename: filename,
      bytes: bytes,
      sizeBytes: bytes.length,
      mediaType: _capturedMediaType(filename),
    );
  }

  Future<List<PickedMedia>> _pickFiles({
    required List<String> extensions,
    required int maxRead,
    required bool image,
  }) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null) return const [];
    final picked = <PickedMedia>[];
    for (final file in result.files) {
      picked.add(await _fromPlatformFile(file, maxRead: maxRead, image: image));
    }
    return picked;
  }

  Future<PickedMedia> _fromPlatformFile(
    PlatformFile file, {
    required int maxRead,
    required bool image,
  }) async {
    final filename = file.name.trim().isEmpty ? 'attachment' : file.name.trim();
    final mediaType = image ? _knownImageMediaType(filename) : null;
    if (file.size > maxRead) {
      return PickedMedia(
        filename: filename,
        bytes: Uint8List(0),
        sizeBytes: file.size,
        mediaType: mediaType,
      );
    }
    var bytes = file.bytes;
    final path = file.path;
    if (bytes == null && path != null) {
      bytes = await File(path).readAsBytes();
    }
    final data = bytes == null ? Uint8List(0) : Uint8List.fromList(bytes);
    return PickedMedia(
      filename: filename,
      bytes: data,
      sizeBytes: data.length,
      mediaType: mediaType,
    );
  }
}

/// Prefer the filename. Camera and gallery shots without a known extension
/// are jpeg because capture requests compressed output.
String _capturedMediaType(String filename) {
  return _knownImageMediaType(filename) ?? 'image/jpeg';
}

/// Null when the extension is not a vision type, so file picks are rejected.
String? _knownImageMediaType(String filename) {
  final ext = p.extension(filename).toLowerCase();
  return imageExtensionMediaTypes[ext];
}
