import 'package:flutter/material.dart';

import '../agent/backend_factory.dart';
import '../agent/remote/remote_jarvis_api.dart';
import 'chat_screen.dart';

/// Admin-only remote cache inspector (home FastAPI). Not used in local mode.
class SessionManagerScreen extends StatefulWidget {
  const SessionManagerScreen({super.key});

  @override
  State<SessionManagerScreen> createState() => _SessionManagerScreenState();
}

class _SessionManagerScreenState extends State<SessionManagerScreen> {
  final _factory = BackendFactory();
  RemoteJarvisApi? _api;
  List<(String, String)> _sessions = [];
  List<String> _validModels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<RemoteJarvisApi> _remote() async {
    return _api ??= await _factory.createRemote();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = await _remote();
      final status = await api.getCacheStatus();
      _validModels = status.agentModels;
      _sessions = status.sessions;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load cache status')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteSession(String model, String threadId) async {
    try {
      final api = await _remote();
      await api.resetSession(threadId: threadId);
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete session')),
      );
    }
  }

  Future<void> _clearGlobal() async {
    try {
      final api = await _remote();
      await api.resetGlobalMemory();
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to clear global cache')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Manager'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Back to chat',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
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
                    label: const Text('Clear entire cache'),
                    onPressed: _clearGlobal,
                  ),
                ),
              ],
            ),
    );
  }
}
