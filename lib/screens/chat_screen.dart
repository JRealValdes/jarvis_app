import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/attachments/device_attachment_picker.dart';
import '../agent/attachments/image_payload.dart';
import '../agent/attachments/outgoing_ask.dart';
import '../agent/attachments/pending_attachment.dart';
import '../agent/chat_controller.dart';
import '../agent/remote/remote_jarvis_api.dart';
import '../agent/speech/composer_mic_controller.dart';
import '../agent/speech/mic_clip_path.dart';
import '../agent/speech/openai_whisper_client.dart';
import '../agent/speech/prompt_text.dart';
import '../agent/speech/prompt_transcriber.dart';
import '../agent/speech/record_mic_session.dart';
import '../agent/speech/speech_route.dart';
import '../agent/speech/transcription_errors.dart';
import '../config/app_config.dart';
import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import '../widgets/attachment_sheets.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message_bubble.dart';
import 'login_screen.dart';
import 'session_manager_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chat = ChatController();
  final _input = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _store = SecureStore();
  final _picker = DeviceAttachmentPicker();
  final List<PendingAttachment> _attachments = [];
  late final ComposerMicController _mic;
  final _micWatch = Stopwatch();
  Timer? _micTicker;
  bool _wasAtBottom = true;
  bool _offlineSnackShown = false;
  bool _preparingSend = false;
  int _attachmentSeq = 0;
  String? _apiBaseUrl;

  void _rebuild() {
    if (mounted) setState(() {});
    _scrollToBottom();
    if (_chat.offlineActive && !_offlineSnackShown) {
      _offlineSnackShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to offline mode. Messages will not be saved.'),
          ),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _mic = ComposerMicController(
      session: RecordMicSession(),
      transcriber: PromptTranscriber(
        remote: RemoteAudioTranscriber(RemoteJarvisApi()),
        localForKey: (key) => OpenAiWhisperClient(apiKey: key),
      ),
      readContext: () async => SpeechContext(
        mode: _chat.mode,
        offlineActive: _chat.offlineActive,
        openAiApiKey: await _store.getOpenAiApiKey(),
      ),
      newClipPath: newMicClipPath,
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.position.pixels;
      _wasAtBottom = (max - current).abs() < 50;
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _wasAtBottom) {
        _scrollToBottom();
      }
    });
    _input.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chat.bootstrap(onUpdate: _rebuild);
      unawaited(_loadApiBaseUrl());
      unawaited(_recoverLostCapture());
    });
  }

  Future<void> _loadApiBaseUrl() async {
    final base = await _store.getApiBaseUrl();
    if (!mounted) return;
    setState(() => _apiBaseUrl = base);
  }

  @override
  void dispose() {
    _micTicker?.cancel();
    unawaited(_mic.dispose());
    _scrollController.dispose();
    _focusNode.dispose();
    _input.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  bool get _composerIdle =>
      _mic.phase == ComposerMicPhase.idle &&
      !_chat.sending &&
      !_preparingSend &&
      !_chat.needsOfflineKey;

  bool get _canSend =>
      _composerIdle &&
      (_input.text.trim().isNotEmpty || _attachments.isNotEmpty);

  int get _imageCount => countAttachments(_attachments, AttachmentKind.image);

  int get _audioCount => countAttachments(_attachments, AttachmentKind.audio);

  Future<SpeechContext> _speechContext() async {
    return SpeechContext(
      mode: _chat.mode,
      offlineActive: _chat.offlineActive,
      openAiApiKey: await _store.getOpenAiApiKey(),
    );
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final typed = _input.text;
    final pending = List<PendingAttachment>.of(_attachments);
    setState(() => _preparingSend = true);
    try {
      final context = await _speechContext();
      final prepared = await prepareOutgoingAsk(
        typed: typed,
        attachments: pending,
        transcribeAudio: (audio) => _mic.transcriber.transcribe(
          bytes: audio.bytes,
          filename: audio.filename,
          context: context,
        ),
      );
      if (!mounted) return;
      _input.clear();
      setState(() => _attachments.clear());
      await _chat.send(
        text: prepared.modelMessage,
        visibleText: prepared.visibleText,
        images: prepared.images,
        media: [
          for (final item in prepared.media)
            if (item.isImage)
              ChatBubbleMedia.image(bytes: item.bytes!, label: item.label)
            else
              ChatBubbleMedia.audio(label: item.label),
        ],
        onUpdate: _rebuild,
      );
    } catch (e) {
      _showFailure(e);
    } finally {
      if (mounted) setState(() => _preparingSend = false);
    }
  }

  Future<void> _openAttachSheet() async {
    if (!_composerIdle) return;
    final imagesAtLimit = _imageCount >= AppConfig.maxImagesPerMessage;
    final audioAtLimit = _audioCount >= AppConfig.maxAudioFilesPerMessage;
    if (imagesAtLimit && audioAtLimit) {
      _showMessage(attachmentLimitMessage(_attachments)!);
      return;
    }
    final kind = await showAttachKindSheet(
      context,
      imagesAtLimit: imagesAtLimit,
      audioAtLimit: audioAtLimit,
    );
    if (!mounted || kind == null) return;
    if (kind == AttachKind.audio) {
      await _pickAudio();
      return;
    }
    final source = await showImageSourceSheet(context);
    if (!mounted || source == null) return;
    if (source == ImagePickSource.gallery) {
      await _pickGallery();
    } else {
      await _pickImageFiles();
    }
  }

  Future<void> _pickGallery() async {
    final remaining = AppConfig.maxImagesPerMessage - _imageCount;
    if (remaining <= 0) {
      _showMessage(
        'At most ${AppConfig.maxImagesPerMessage} images are allowed per message.',
      );
      return;
    }
    try {
      final picked = await _picker.pickGalleryImages(limit: remaining);
      if (!mounted) return;
      _addPicked(AttachmentKind.image, picked);
    } catch (e) {
      _showFailure(e);
    }
  }

  Future<void> _pickImageFiles() async {
    try {
      final picked = await _picker.pickImageFiles();
      if (!mounted) return;
      _addPicked(AttachmentKind.image, picked);
    } catch (e) {
      _showFailure(e);
    }
  }

  Future<void> _pickAudio() async {
    try {
      final picked = await _picker.pickAudioFiles();
      if (!mounted) return;
      _addPicked(AttachmentKind.audio, picked);
    } catch (e) {
      _showFailure(e);
    }
  }

  Future<void> _openCamera() async {
    if (!_composerIdle) return;
    if (_imageCount >= AppConfig.maxImagesPerMessage) {
      _showMessage(
        'At most ${AppConfig.maxImagesPerMessage} images are allowed per message.',
      );
      return;
    }
    while (mounted) {
      final PickedMedia? shot;
      try {
        shot = await _picker.capturePhoto();
      } catch (e) {
        _showFailure(e);
        return;
      }
      if (shot == null || !mounted) return;
      final action = await showCameraConfirmDialog(context, shot.bytes);
      if (!mounted) return;
      if (action == CameraConfirmAction.retake) continue;
      if (action == CameraConfirmAction.use) {
        _addPicked(AttachmentKind.image, [shot]);
      }
      return;
    }
  }

  Future<void> _recoverLostCapture() async {
    try {
      final shot = await _picker.recoverLostCapture();
      if (shot == null || !mounted) return;
      if (_imageCount >= AppConfig.maxImagesPerMessage) return;
      final action = await showCameraConfirmDialog(context, shot.bytes);
      if (!mounted || action != CameraConfirmAction.use) return;
      _addPicked(AttachmentKind.image, [shot]);
    } catch (_) {}
  }

  void _addPicked(AttachmentKind kind, List<PickedMedia> picked) {
    if (picked.isEmpty) return;
    final intake = intakeAttachments(
      existing: _attachments,
      kind: kind,
      picked: picked,
      nextId: () => 'att-${_attachmentSeq++}',
    );
    setState(() => _attachments.addAll(intake.accepted));
    if (intake.notices.isNotEmpty) {
      _showMessage(intake.notices.join('\n'));
    }
  }

  void _removeAttachment(String id) {
    setState(() => _attachments.removeWhere((item) => item.id == id));
  }

  void _showFailure(Object error) {
    final text = error.toString().toLowerCase();
    if (error is ImageAttachmentException) {
      _showMessage(error.message);
      return;
    }
    if (text.contains('camera_access_denied') ||
        text.contains('photo_access_denied') ||
        text.contains('permission')) {
      _showMessage(
        'Permission is required to attach that file. '
        'Enable it for Jarvis in system settings.',
      );
      return;
    }
    if (text.contains('no_available_camera') || text.contains('no cameras')) {
      _showMessage('No camera is available on this device.');
      return;
    }
    _showMessage(describeTranscriptionError(error));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startMicTicker() {
    _micTicker?.cancel();
    _micTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_mic.phase != ComposerMicPhase.recording) return;
      setState(() {});
    });
  }

  Future<void> _abandonMic() async {
    _micTicker?.cancel();
    _micWatch.stop();
    _micWatch.reset();
    await _mic.cancel();
  }

  Future<void> _startMic() async {
    _focusNode.unfocus();
    try {
      await _mic.start();
      _micWatch
        ..reset()
        ..start();
      _startMicTicker();
      if (mounted) setState(() {});
    } on MicPermissionDeniedException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Could not start recording. $e');
    }
  }

  Future<void> _toggleMicPause() async {
    if (_mic.phase == ComposerMicPhase.recording) {
      _micWatch.stop();
      _micTicker?.cancel();
      try {
        await _mic.pause();
      } catch (e) {
        _micWatch.start();
        _startMicTicker();
        _showMessage('Could not pause recording. $e');
      }
    } else if (_mic.phase == ComposerMicPhase.paused) {
      try {
        await _mic.resume();
        _micWatch.start();
        _startMicTicker();
      } catch (e) {
        _showMessage('Could not resume recording. $e');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _cancelMic() async {
    await _abandonMic();
    if (mounted) setState(() {});
  }

  Future<void> _finishMic() async {
    _micWatch.stop();
    _micTicker?.cancel();
    try {
      final spoken = await _mic.finish();
      if (!mounted || spoken == null) return;
      if (spoken.trim().isEmpty) {
        _showMessage('No speech detected.');
        return;
      }
      _input.text = mergeDictationIntoPrompt(_input.text, spoken);
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _focusNode.requestFocus();
    } catch (e) {
      _showMessage(describeTranscriptionError(e));
    } finally {
      _micWatch.reset();
      if (mounted) setState(() {});
    }
  }

  Future<void> _reset() async {
    await _abandonMic();
    setState(() => _attachments.clear());
    try {
      await _chat.resetChat(onUpdate: _rebuild);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    }
  }

  Future<void> _logoutRemote() async {
    await _abandonMic();
    await _chat.logoutRemote();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String get _title {
    switch (_chat.mode) {
      case JarvisMode.local:
        return 'J.A.R.V.I.S. (local)';
      case JarvisMode.remote:
        return 'J.A.R.V.I.S. (remote)';
      case JarvisMode.auto:
        return _chat.offlineActive
            ? 'J.A.R.V.I.S. (offline)'
            : 'J.A.R.V.I.S. (auto)';
    }
  }

  bool get _showAdmin =>
      _chat.isAdmin &&
      (_chat.mode == JarvisMode.remote ||
          (_chat.mode == JarvisMode.auto && !_chat.offlineActive));

  bool get _showRemoteLogout =>
      _chat.mode == JarvisMode.remote ||
      (_chat.mode == JarvisMode.auto && !_chat.offlineActive);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await _abandonMic();
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (!context.mounted) return;
              _offlineSnackShown = false;
              await _loadApiBaseUrl();
              await _chat.bootstrap(onUpdate: _rebuild);
            },
          ),
          if (_showAdmin)
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: 'Session Manager',
              onPressed: () async {
                await _abandonMic();
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SessionManagerScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset chat',
            onPressed: _reset,
          ),
          if (_showRemoteLogout)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: _logoutRemote,
            ),
        ],
      ),
      body: _chat.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_chat.offlineActive)
                  Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: const ListTile(
                      dense: true,
                      leading: Icon(Icons.cloud_off),
                      title: Text(
                        'Offline mode: messages handled here will not be saved.',
                      ),
                    ),
                  ),
                if (_chat.slowRemoteOfferVisible)
                  Material(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.hourglass_top),
                      title: const Text(
                        'The server is taking longer than usual. Switch to offline?',
                      ),
                      subtitle: _chat.slowRemoteCanGoOffline
                          ? null
                          : const Text('Remote-only mode cannot go offline.'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _chat.keepWaitingOnRemote(onUpdate: _rebuild),
                            child: const Text('Keep waiting'),
                          ),
                          if (_chat.slowRemoteCanGoOffline)
                            TextButton(
                              onPressed: () =>
                                  _chat.switchToOfflineNow(onUpdate: _rebuild),
                              child: const Text('Go offline'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_chat.needsOfflineKey)
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.key),
                      title: const Text(
                        'Server unreachable. Add an OpenAI API key for offline mode.',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await _abandonMic();
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          if (!mounted) return;
                          await _chat.bootstrap(onUpdate: _rebuild);
                        },
                        child: const Text('Settings'),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _chat.messages.length,
                    itemBuilder: (context, index) {
                      final m = _chat.messages[index];
                      return ChatMessageBubble(
                        text: m.text,
                        isUser: m.isUser,
                        media: m.media,
                        apiBaseUrl: _apiBaseUrl,
                      );
                    },
                  ),
                ),
                if (_chat.sending || _preparingSend)
                  const LinearProgressIndicator(minHeight: 2),
                ChatComposer(
                  controller: _input,
                  focusNode: _focusNode,
                  phase: _mic.phase,
                  elapsed: _micWatch.elapsed,
                  inputEnabled: _composerIdle,
                  attachments: _attachments,
                  limitMessage: attachmentLimitMessage(_attachments),
                  onSend: _canSend ? _send : null,
                  onMic: _composerIdle ? _startMic : null,
                  onAttach: _composerIdle ? _openAttachSheet : null,
                  onCamera: _composerIdle ? _openCamera : null,
                  onRemoveAttachment: _composerIdle ? _removeAttachment : null,
                  onCancel: _cancelMic,
                  onTogglePause: _toggleMicPause,
                  onFinish: _finishMic,
                ),
              ],
            ),
    );
  }
}
