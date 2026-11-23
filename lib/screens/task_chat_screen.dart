import 'package:flutter/material.dart';

import '../agent/chat_controller.dart';
import '../domain/models/jarvis_mode.dart';
import '../domain/models/periodic_task.dart';
import '../widgets/chat_message_bubble.dart';
import 'task_edit_screen.dart';

/// Ephemeral chat for one periodic task (seeded report + follow-ups).
class TaskChatScreen extends StatefulWidget {
  const TaskChatScreen({super.key, required this.task});

  final PeriodicTask task;

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  late final ChatController _chat;
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _chat = ChatController(
      threadId: widget.task.threadId,
      isTaskChat: true,
      resetBanner: widget.task.nextResetBanner,
    );
    _chat.bootstrap(onUpdate: _rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _chat.sending) return;
    _input.clear();
    setState(() => _sending = true);
    await _chat.send(text: text, onUpdate: _rebuild);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<PeriodicTask>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(task: widget.task),
      ),
    );
    if (updated != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TaskChatScreen(task: updated)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _chat.resetBanner ?? widget.task.nextResetBanner;
    final remoteOk =
        _chat.mode == JarvisMode.remote ||
        (_chat.mode == JarvisMode.auto && !_chat.offlineActive);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit task',
            onPressed: _openEdit,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.schedule),
              title: Text(banner),
            ),
          ),
          Expanded(
            child: _chat.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _chat.messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          _chat.messages[_chat.messages.length - 1 - index];
                      return ChatMessageBubble(
                        text: msg.text,
                        isUser: msg.isUser,
                      );
                    },
                  ),
          ),
          if (_chat.sending || _sending)
            const LinearProgressIndicator(minHeight: 2),
          if (!remoteOk)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Periodic tasks require Remote mode with a reachable server.',
                textAlign: TextAlign.center,
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Ask about this run…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: (_chat.sending || _sending) ? null : _send,
                      icon: const Icon(Icons.send),
                      tooltip: 'Send',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
