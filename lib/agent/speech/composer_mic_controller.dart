import 'dart:io';

import 'package:path/path.dart' as p;

import 'mic_session.dart';
import 'prompt_transcriber.dart';
import 'speech_route.dart';
import 'transcription_errors.dart';

enum ComposerMicPhase { idle, recording, paused, transcribing }

/// Record / pause / resume / cancel / finish for one composer utterance.
///
/// The clip is deleted on cancel, after a successful read, and if finish fails.
class ComposerMicController {
  ComposerMicController({
    required this.session,
    required this.transcriber,
    required this.readContext,
    required this.newClipPath,
    this.onUpdate,
  });

  final MicSession session;
  final PromptTranscriber transcriber;
  final Future<SpeechContext> Function() readContext;
  final Future<String> Function() newClipPath;
  void Function()? onUpdate;

  ComposerMicPhase phase = ComposerMicPhase.idle;

  String? _clipPath;
  bool _finishInFlight = false;

  Future<void> start() async {
    if (phase != ComposerMicPhase.idle || _finishInFlight) return;
    final allowed = await session.hasPermission();
    if (!allowed) {
      throw const MicPermissionDeniedException();
    }
    final path = await newClipPath();
    _clipPath = path;
    try {
      await session.start(path: path);
    } catch (e) {
      await _deleteClip(path);
      _clipPath = null;
      rethrow;
    }
    phase = ComposerMicPhase.recording;
    onUpdate?.call();
  }

  Future<void> pause() async {
    if (phase != ComposerMicPhase.recording) return;
    await session.pause();
    phase = ComposerMicPhase.paused;
    onUpdate?.call();
  }

  Future<void> resume() async {
    if (phase != ComposerMicPhase.paused) return;
    await session.resume();
    phase = ComposerMicPhase.recording;
    onUpdate?.call();
  }

  Future<void> cancel() async {
    if (phase != ComposerMicPhase.recording &&
        phase != ComposerMicPhase.paused) {
      return;
    }
    try {
      await session.cancel();
    } finally {
      await _deleteClip(_clipPath);
      _clipPath = null;
      phase = ComposerMicPhase.idle;
      onUpdate?.call();
    }
  }

  /// Transcribed text, or null when finish was ignored (already idle / in flight).
  Future<String?> finish() async {
    if (_finishInFlight) return null;
    if (phase != ComposerMicPhase.recording &&
        phase != ComposerMicPhase.paused) {
      return null;
    }
    _finishInFlight = true;
    phase = ComposerMicPhase.transcribing;
    onUpdate?.call();
    try {
      return await _captureAndTranscribe();
    } finally {
      await _deleteClip(_clipPath);
      _clipPath = null;
      _finishInFlight = false;
      phase = ComposerMicPhase.idle;
      onUpdate?.call();
    }
  }

  Future<void> dispose() async {
    if (phase == ComposerMicPhase.recording ||
        phase == ComposerMicPhase.paused) {
      try {
        await session.cancel();
      } catch (_) {}
      await _deleteClip(_clipPath);
      _clipPath = null;
    }
    phase = ComposerMicPhase.idle;
    await session.dispose();
  }

  Future<String> _captureAndTranscribe() async {
    final startedAt = _clipPath;
    final stopped = await session.stop();
    final clip = (stopped != null && stopped.isNotEmpty) ? stopped : startedAt;
    if (clip == null) {
      throw const SpeechTranscriptionException('Recording was empty.');
    }
    _clipPath = clip;
    final file = File(clip);
    if (!await file.exists()) {
      throw const SpeechTranscriptionException('Recording was empty.');
    }
    final bytes = await file.readAsBytes();
    final filename = p.basename(clip);
    await _deleteClip(clip);
    if (startedAt != null && startedAt != clip) {
      await _deleteClip(startedAt);
    }
    _clipPath = null;
    final context = await readContext();
    return transcriber.transcribe(
      bytes: bytes,
      filename: filename,
      context: context,
    );
  }

  Future<void> _deleteClip(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
