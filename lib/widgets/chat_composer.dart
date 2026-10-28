import 'package:flutter/material.dart';

import '../agent/speech/composer_mic_controller.dart';
import '../agent/speech/prompt_text.dart';

const composerMicKey = Key('composer_mic');

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: switch (phase) {
        ComposerMicPhase.transcribing => const _TranscribingBar(),
        ComposerMicPhase.recording || ComposerMicPhase.paused => _RecordingBar(
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
          ),
      },
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool inputEnabled;
  final VoidCallback? onSend;
  final VoidCallback? onMic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
          key: composerMicKey,
          tooltip: 'Dictate',
          onPressed: onMic,
          icon: const Icon(Icons.mic),
        ),
        IconButton(
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
