import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/app_config.dart';

enum AttachKind { image, audio }

enum ImagePickSource { gallery, files }

enum CameraConfirmAction { use, retake }

const attachImageChoiceKey = Key('attach_choice_image');
const attachAudioChoiceKey = Key('attach_choice_audio');
const imageGalleryChoiceKey = Key('attach_image_gallery');
const imageFilesChoiceKey = Key('attach_image_files');
const cameraUsePhotoKey = Key('camera_use_photo');
const cameraRetakeKey = Key('camera_retake');

/// Icon-first chooser: image or audio.
Future<AttachKind?> showAttachKindSheet(
  BuildContext context, {
  required bool imagesAtLimit,
  required bool audioAtLimit,
}) {
  return showModalBottomSheet<AttachKind>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attach',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Images are shown to Jarvis. Audio is transcribed as context.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Choice(
                    key: attachImageChoiceKey,
                    icon: Icons.image_outlined,
                    label: 'Image',
                    subtitle: imagesAtLimit
                        ? 'Limit reached (${AppConfig.maxImagesPerMessage})'
                        : 'Gallery or files',
                    onPressed: imagesAtLimit
                        ? null
                        : () => Navigator.pop(context, AttachKind.image),
                  ),
                  const SizedBox(width: 12),
                  _Choice(
                    key: attachAudioChoiceKey,
                    icon: Icons.audio_file_outlined,
                    label: 'Audio',
                    subtitle: audioAtLimit
                        ? 'Limit reached (${AppConfig.maxAudioFilesPerMessage})'
                        : 'Files',
                    onPressed: audioAtLimit
                        ? null
                        : () => Navigator.pop(context, AttachKind.audio),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Gallery or files after the user picks Image.
Future<ImagePickSource?> showImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImagePickSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Image', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Choice(
                    key: imageGalleryChoiceKey,
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    subtitle: 'Photos',
                    onPressed: () =>
                        Navigator.pop(context, ImagePickSource.gallery),
                  ),
                  const SizedBox(width: 12),
                  _Choice(
                    key: imageFilesChoiceKey,
                    icon: Icons.folder_outlined,
                    label: 'Files',
                    subtitle: 'png, jpg, gif, webp',
                    onPressed: () =>
                        Navigator.pop(context, ImagePickSource.files),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Preview a camera shot before it joins the composer.
Future<CameraConfirmAction?> showCameraConfirmDialog(
  BuildContext context,
  Uint8List bytes,
) {
  return showDialog<CameraConfirmAction>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Use this photo?'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            height: 280,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: cameraRetakeKey,
            onPressed: () => Navigator.pop(context, CameraConfirmAction.retake),
            child: const Text('Retake'),
          ),
          FilledButton(
            key: cameraUsePhotoKey,
            onPressed: () => Navigator.pop(context, CameraConfirmAction.use),
            child: const Text('Use photo'),
          ),
        ],
      );
    },
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(label),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
