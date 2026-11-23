import 'package:flutter/material.dart';

import '../agent/backend_factory.dart';
import '../agent/remote/remote_jarvis_api.dart';
import '../domain/models/periodic_task.dart';
import 'task_chat_screen.dart';
import 'task_edit_screen.dart';

/// List of configured periodic tasks (remote JWT only).
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _factory = BackendFactory();
  List<PeriodicTask> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<RemoteJarvisApi> _api() => _factory.createRemote();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await _api();
      final tasks = await api.listTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<PeriodicTask>(
      context,
      MaterialPageRoute(builder: (_) => const TaskEditScreen()),
    );
    if (created != null) await _load();
  }

  Future<void> _open(PeriodicTask task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskChatScreen(task: task)),
    );
    await _load();
  }

  Future<void> _runNow(PeriodicTask task) async {
    try {
      final api = await _api();
      final run = await api.runTaskNow(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Run ${run.status}: ${run.summary ?? ''}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Run failed: $e')),
      );
    }
  }

  Future<void> _delete(PeriodicTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final api = await _api();
      await api.deleteTask(task.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Periodic tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'New task',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _tasks.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No periodic tasks yet.\n'
                          'Create one to run automatic searches on a schedule.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return ListTile(
                          title: Text(task.title),
                          subtitle: Text(
                            '${task.scheduleLabel}\n${task.statusSubtitle}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'run') _runNow(task);
                              if (value == 'delete') _delete(task);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'run',
                                child: Text('Run now'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                          onTap: () => _open(task),
                        );
                      },
                    ),
    );
  }
}
