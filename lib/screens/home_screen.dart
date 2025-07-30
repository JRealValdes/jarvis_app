import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Agrega el mensaje del usuario
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });

    _controller.clear();

    final resp = await _api.postAsk({
      'message': text,
      'model_name': 'GPT_3_5',
      'thread_id': 'test',
    });

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final responses = List<String>.from(decoded['response'] ?? []);

      setState(() {
        for (var msg in responses) {
          _messages.add(ChatMessage(text: msg, isUser: false));
        }
      });
    } else {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: ${resp.statusCode}', isUser: false));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jarvis')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                    decoration: InputDecoration(hintText: 'Escribe un mensaje...'),
                    onSubmitted: (_) => _sendMessage(),
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
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(10),
        child: Text(text),
      ),
    );
  }
}
