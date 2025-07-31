import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class HomeScreen extends StatefulWidget {
  final String? threadId;
  const HomeScreen({super.key, this.threadId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  String? _threadId;

  @override
  void initState() {
    super.initState();
    _threadId = widget.threadId;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    _controller.clear();

    // If there's no threadId, create a new one and save it
    _threadId ??= DateTime.now().millisecondsSinceEpoch.toString();
    await StorageService.saveThreadId(_threadId!);

    print('Enviando mensaje: $text');
    print('Thread ID: $_threadId');

    final resp = await _api.postAsk({
      'message': text,
      'model_name': Config.modelName,
      'thread_id': _threadId!,
    });

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final responses = List<String>.from(decoded['response'] ?? []);

      setState(() {
        for (var msg in responses) {
          _messages.add(ChatMessage(text: msg, isUser: false));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        }
      });
    } else {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: ${resp.statusCode}', isUser: false));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _resetChat() async {
    final response = await _api.resetMemory();

    if (!mounted) return;

    if (response.statusCode == 200) {
      setState(() {
        _messages.clear();
        _threadId = null;
      });
      await StorageService.deleteThreadId();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al resetear: ${response.statusCode}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('J.A.R.V.I.S.'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Resetear chat',
            onPressed: _resetChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
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
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: InputDecoration(hintText: 'Escribe un mensaje...'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
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
