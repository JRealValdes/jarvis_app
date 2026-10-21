import 'package:flutter/material.dart';

import '../agent/chat_controller.dart';
import '../domain/models/jarvis_mode.dart';
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
  bool _wasAtBottom = true;

  void _rebuild() {
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chat.bootstrap(onUpdate: _rebuild);
    });
  }

  @override
  void dispose() {
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

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    await _chat.send(text: text, onUpdate: _rebuild);
  }

  Future<void> _reset() async {
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
    await _chat.logoutRemote();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chat.mode == JarvisMode.local
              ? 'J.A.R.V.I.S. (local)'
              : 'J.A.R.V.I.S. (remote)',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (!mounted) return;
              await _chat.bootstrap(onUpdate: _rebuild);
            },
          ),
          if (_chat.isAdmin && _chat.mode == JarvisMode.remote)
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: 'Session Manager',
              onPressed: () async {
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
          if (_chat.mode == JarvisMode.remote)
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
                      );
                    },
                  ),
                ),
                if (_chat.sending) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          enabled: !_chat.sending,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _chat.sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
