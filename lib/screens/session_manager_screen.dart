import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class SessionManagerScreen extends StatefulWidget {
  const SessionManagerScreen({super.key});

  @override
  State<SessionManagerScreen> createState() => _SessionManagerScreenState();
}

class _SessionManagerScreenState extends State<SessionManagerScreen> {
  final ApiService _api = ApiService();
  List<(String, String)> _sessions = [];
  List<String> _validModels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final resp = await _api.getCacheStatus();
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      _validModels = List<String>.from(data['agent_models'] ?? []);
      _sessions = List<String>.from(data['sessions'] ?? [])
          .map((s) => s.replaceAll("('", '').replaceAll("')", '').split(", "))
          .map((list) => (list[0], list[1].replaceAll("'", "")))
          .toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteSession(String model, String threadId) async {
    final resp = await _api.resetSession(threadId: threadId);
    if (resp.statusCode == 200) {
      _loadData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar sesión')));
    }
  }

  Future<void> _clearGlobal() async {
    final resp = await _api.resetGlobalMemory();
    if (resp.statusCode == 200) {
      _loadData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar globalmente')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final (model, threadId) = _sessions[index];
                      final isValid = _validModels.contains(model);
                      return Container(
                        color: isValid ? null : Colors.red[100],
                        child: ListTile(
                          title: Text('Model: $model'),
                          subtitle: Text('Thread ID: $threadId'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteSession(model, threadId),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.warning),
                    label: const Text('Borrar toda la caché'),
                    onPressed: _clearGlobal,
                  ),
                )
              ],
            ),
    );
  }
}
