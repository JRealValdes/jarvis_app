import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'session_manager_screen.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isAdmin = false;
  bool _wasAtBottom = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    AuthService().isAdmin().then((value) {
      setState(() {
        _isAdmin = value;
      });
    });

    // Detectar si estaba abajo al hacer scroll
    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.position.pixels;
      _wasAtBottom = (max - current).abs() < 50;
    });

    // Al aparecer el teclado (cuando el campo de texto gana foco)
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshChat();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshChat() async {
    setState(() {
      _loading = true;
      _messages.clear();
    });

    final resp = await _api.getMessageHistory();

    if (!mounted) return;

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final history = decoded['messages'] as List<dynamic>;

      if (history.isEmpty) {
        setState(() => _loading = false);
        _sendMessage(initial: true);
        return;
      }

      setState(() {
        for (var msg in history) {
          if (msg['role'] == 'system') continue;
          final isUser = msg['role'] == 'user';
          _messages.add(ChatMessage(text: msg['content'], isUser: isUser));
        }
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      _sendMessage(initial: true);
    }
  }

  void _sendMessage({bool initial = false}) async {
    final String text;
    if (initial) {
      text = "Hola";
      final resp = await _api.resetSession();
      if (resp.statusCode != 200) {
        setState(() {
          _messages.add(ChatMessage(text: 'Error al resetear: ${resp.statusCode}', isUser: false));
        });
        return;
      }
    } else {
      text = _controller.text.trim();
      if (text.isEmpty) return;
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: true));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      _controller.clear();
    }

    final resp = await _api.postAsk({
      'message': text,
      'model_name': Config.modelName,
    });

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final responses = List<String>.from(decoded['response'] ?? []);

      if (responses.isNotEmpty) {
        setState(() {
          for (var msg in responses) {
            _messages.add(ChatMessage(text: msg, isUser: false));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        });
      }
    } else {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: ${resp.statusCode}', isUser: false));
      });
    }
  }

  Future<void> _resetChat() async {
    final response = await _api.resetSession();

    if (!mounted) return;

    if (response.statusCode == 200) {
      setState(() {
        _messages.clear();
      });
      _sendMessage(initial: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al resetear: ${response.statusCode}')),
      );
    }
  }

  Future<void> _logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'username');
    await storage.delete(key: 'password');

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
        automaticallyImplyLeading: false, // ⛔ Do not show "back" button
        title: const Text('J.A.R.V.I.S.'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: 'Session Manager',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionManagerScreen()),
                );
                _refreshChat(); // Refresh when returning from Session Manager Screen
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Resetear chat',
            onPressed: _resetChat,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
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
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
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
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: isUser
            ? Text(text)
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium,
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                  h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}
