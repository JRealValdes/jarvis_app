import 'package:flutter/material.dart';

import '../agent/backend_factory.dart';
import '../agent/jarvis_backend.dart';
import '../config/app_config.dart';
import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import '../services/auth_service.dart';
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
  final _factory = BackendFactory();
  final _secureStore = SecureStore();
  final _auth = AuthService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_Bubble> _messages = [];

  JarvisBackend? _backend;
  JarvisMode _mode = JarvisMode.local;
  String _modelName = 'gpt-4o-mini';
  bool _isAdmin = false;
  bool _wasAtBottom = true;
  bool _loading = false;
  bool _sending = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final mode = await _secureStore.getMode();
    // Remote FastAPI expects ModelEnum labels; local uses OpenAI model ids.
    final model = mode == JarvisMode.remote
        ? AppConfig.defaultRemoteModelEnum
        : await _secureStore.getOpenAiModel();
    final backend = await _factory.create();
    var isAdmin = false;
    if (mode == JarvisMode.remote) {
      isAdmin = await _auth.isAdmin();
    }
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _modelName = model;
      _backend = backend;
      _isAdmin = isAdmin;
    });
    await _refreshChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _controller.dispose();
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

  Future<void> _refreshChat() async {
    final backend = _backend;
    if (backend == null) return;

    setState(() {
      _loading = true;
      _messages.clear();
    });

    try {
      final history = await backend.getMessageHistory();
      final cacheExists = await backend.individualCacheExists();
      if (!mounted) return;

      if (history.isEmpty) {
        if (cacheExists) {
          await backend.resetSession();
        }
        setState(() => _loading = false);
        await _sendMessage(initial: true);
        return;
      }

      setState(() {
        for (final msg in history) {
          if (msg.isSystem) continue;
          _messages.add(_Bubble(text: msg.content, isUser: msg.isUser));
        }
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _sendMessage(initial: true);
    }
  }

  Future<void> _sendMessage({bool initial = false}) async {
    final backend = _backend;
    if (backend == null || _sending) return;

    final String text;
    if (initial) {
      text = 'Hola';
      try {
        await backend.resetSession();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _messages.add(_Bubble(text: 'Error al resetear: $e', isUser: false));
        });
        return;
      }
    } else {
      text = _controller.text.trim();
      if (text.isEmpty) return;
      setState(() {
        _messages.add(_Bubble(text: text, isUser: true));
      });
      _scrollToBottom();
      _controller.clear();
    }

    setState(() => _sending = true);
    try {
      final responses = await backend.ask(text, modelName: _modelName);
      if (!mounted) return;
      setState(() {
        for (final msg in responses) {
          _messages.add(_Bubble(text: msg, isUser: false));
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Bubble(text: 'Error: $e', isUser: false));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resetChat() async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.resetSession();
      if (!mounted) return;
      setState(() => _messages.clear());
      await _sendMessage(initial: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al resetear: $e')),
      );
    }
  }

  Future<void> _logoutRemote() async {
    await _auth.logout();
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
          _mode == JarvisMode.local
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
              await _bootstrap();
            },
          ),
          if (_isAdmin && _mode == JarvisMode.remote)
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
            tooltip: 'Resetear chat',
            onPressed: _resetChat,
          ),
          if (_mode == JarvisMode.remote)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _logoutRemote,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      return ChatMessageBubble(
                        text: m.text,
                        isUser: m.isUser,
                      );
                    },
                  ),
                ),
                if (_sending) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje...',
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sending ? null : () => _sendMessage(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Bubble {
  _Bubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}
