import 'package:flutter/material.dart';

import '../agent/attachments/pending_attachment.dart';
import '../agent/speech/composer_mic_controller.dart';
import '../agent/speech/prompt_text.dart';

const composerMicKey = Key('composer_mic');
const composerAttachKey = Key('composer_attach');
const composerCameraKey = Key('composer_camera');

/// Chat input, or the record / transcribe bar that replaces it.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.phase,
    required this.elapsed,
    required this.inputEnabled,
    required this.onSend,
    required this.onMic,
    required this.onCancel,
    required this.onTogglePause,
    required this.onFinish,
    this.attachments = const [],
    this.limitMessage,
    this.onAttach,
    this.onCamera,
    this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ComposerMicPhase phase;
  final Duration elapsed;
  final bool inputEnabled;
  final VoidCallback? onSend;
  final VoidCallback? onMic;
  final VoidCallback? onCancel;
  final VoidCallback? onTogglePause;
  final VoidCallback? onFinish;
  final List<PendingAttachment> attachments;
  final String? limitMessage;
  final VoidCallback? onAttach;
  final VoidCallback? onCamera;
  final void Function(String id)? onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attachments.isNotEmpty)
            _AttachmentStrip(
              attachments: attachments,
              onRemove: inputEnabled ? onRemoveAttachment : null,
            ),
          if (limitMessage != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                limitMessage!,
                key: const Key('composer_limit'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          switch (phase) {
            ComposerMicPhase.transcribing => const _TranscribingBar(),
            ComposerMicPhase.recording || ComposerMicPhase.paused =>
              _RecordingBar(
                paused: phase == ComposerMicPhase.paused,
                elapsed: elapsed,
                onCancel: onCancel,
                onTogglePause: onTogglePause,
                onFinish: onFinish,
              ),
            ComposerMicPhase.idle => _IdleComposer(
                controller: controller,
                focusNode: focusNode,
                inputEnabled: inputEnabled,
                onSend: onSend,
                onMic: onMic,
                onAttach: onAttach,
                onCamera: onCamera,
              ),
          },
        ],
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<PendingAttachment> attachments;
  final void Function(String id)? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('composer_attachments'),
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = attachments[index];
          return _AttachmentChip(item: item, onRemove: onRemove);
        },
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.item, required this.onRemove});

  final PendingAttachment item;
  final void Function(String id)? onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      key: Key('attachment_${item.id}'),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(item.filename, overflow: TextOverflow.ellipsis),
      ),
      avatar: item.isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                item.bytes,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image, size: 18),
              ),
            )
          : const Icon(Icons.audio_file, size: 18),
      onDeleted: onRemove == null ? null : () => onRemove!(item.id),
      deleteIcon: Icon(
        Icons.close,
        key: Key('attachment_remove_${item.id}'),
        size: 18,
      ),
    );
  }
}

class _IdleComposer extends StatelessWidget {
  const _IdleComposer({
    required this.controller,
    required this.focusNode,
    required this.inputEnabled,
    required this.onSend,
    required this.onMic,
    required this.onAttach,
    required this.onCamera,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool inputEnabled;
  final VoidCallback? onSend;
  final VoidCallback? onMic;
  final VoidCallback? onAttach;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    const buttonConstraints = BoxConstraints(minWidth: 40, minHeight: 40);
    return Row(
      children: [
        IconButton(
          key: composerAttachKey,
          tooltip: 'Attach',
          visualDensity: VisualDensity.compact,
          constraints: buttonConstraints,
          onPressed: inputEnabled ? onAttach : null,
          icon: const Icon(Icons.attach_file),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            enabled: inputEnabled,
            decoration: const InputDecoration(
              hintText: 'Type a message...',
            ),
            onSubmitted: onSend == null ? null : (_) => onSend!(),
          ),
        ),
        IconButton(
          key: composerCameraKey,
          tooltip: 'Camera',
          visualDensity: VisualDensity.compact,
          constraints: buttonConstraints,
          onPressed: inputEnabled ? onCamera : null,
          icon: const Icon(Icons.photo_camera),
        ),
        IconButton(
          key: composerMicKey,
          tooltip: 'Dictate',
          visualDensity: VisualDensity.compact,
          constraints: buttonConstraints,
          onPressed: onMic,
          icon: const Icon(Icons.mic),
        ),
        IconButton(
          tooltip: 'Send',
          visualDensity: VisualDensity.compact,
          constraints: buttonConstraints,
          icon: const Icon(Icons.send),
          onPressed: onSend,
        ),
      ],
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.paused,
    required this.elapsed,
    required this.onCancel,
    required this.onTogglePause,
    required this.onFinish,
  });

  final bool paused;
  final Duration elapsed;
  final VoidCallback? onCancel;
  final VoidCallback? onTogglePause;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final clock = formatRecordingClock(elapsed);
    final label = paused ? 'Paused $clock' : 'Recording $clock';
    final buttonStyle = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      children: [
        TextButton(
          style: buttonStyle,
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          style: buttonStyle,
          onPressed: onTogglePause,
          child: Text(paused ? 'Resume' : 'Pause'),
        ),
        TextButton(
          style: buttonStyle,
          onPressed: onFinish,
          child: const Text('Finish'),
        ),
      ],
    );
  }
}

class _TranscribingBar extends StatelessWidget {
  const _TranscribingBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Text('Transcribing…')),
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    );
  }
}
