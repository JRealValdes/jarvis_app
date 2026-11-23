import 'package:flutter/material.dart';

import '../agent/backend_factory.dart';
import '../domain/models/periodic_task.dart';

const _weekdays = <(String, String)>[
  ('mon', 'Mon'),
  ('tue', 'Tue'),
  ('wed', 'Wed'),
  ('thu', 'Thu'),
  ('fri', 'Fri'),
  ('sat', 'Sat'),
  ('sun', 'Sun'),
];

/// Create or edit a periodic task via the FastAPI form contract.
class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key, this.task});

  final PeriodicTask? task;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _factory = BackendFactory();
  final _title = TextEditingController();
  final _instruction = TextEditingController();
  final _time = TextEditingController(text: '08:00');
  final _timezone = TextEditingController(text: 'Europe/Madrid');
  final _selectedDays = <String>{'mon', 'tue', 'wed', 'thu', 'fri'};
  String _notifyPolicy = 'always';
  bool _enabled = true;
  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task == null) return;
    _title.text = task.title;
    _instruction.text = task.instruction;
    _timezone.text = task.timezone;
    _notifyPolicy = task.notifyPolicy;
    _enabled = task.enabled;
    final time = task.schedule['time'];
    if (time is String && time.isNotEmpty) _time.text = time;
    final days = task.schedule['days_of_week'];
    if (days is List && days.isNotEmpty) {
      _selectedDays
        ..clear()
        ..addAll(days.map((d) => _normalizeDay(d)).whereType<String>());
    }
  }

  String? _normalizeDay(Object? raw) {
    if (raw is int) {
      const map = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      if (raw >= 0 && raw < map.length) return map[raw];
      return null;
    }
    final text = '$raw'.trim().toLowerCase();
    if (text.isEmpty) return null;
    if (text.length >= 3) return text.substring(0, 3);
    return text;
  }

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    _time.dispose();
    _timezone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final instruction = _instruction.text.trim();
    final time = _time.text.trim();
    if (title.isEmpty || instruction.isEmpty || time.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title, instruction, and time are required.')),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one weekday.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = await _factory.createRemote();
      final PeriodicTask saved;
      if (_isEdit) {
        saved = await api.updateTask(
          widget.task!.id,
          title: title,
          instruction: instruction,
          daysOfWeek: _selectedDays.toList(),
          time: time,
          timezone: _timezone.text.trim(),
          notifyPolicy: _notifyPolicy,
          enabled: _enabled,
        );
      } else {
        saved = await api.createTask(
          title: title,
          instruction: instruction,
          daysOfWeek: _selectedDays.toList(),
          time: time,
          timezone: _timezone.text.trim(),
          notifyPolicy: _notifyPolicy,
          enabled: _enabled,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit task' : 'New task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instruction,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Instruction / goal',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Days of week'),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _weekdays)
                FilterChip(
                  label: Text(entry.$2),
                  selected: _selectedDays.contains(entry.$1),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(entry.$1);
                      } else {
                        _selectedDays.remove(entry.$1);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _time,
            decoration: const InputDecoration(
              labelText: 'Time (HH:MM)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timezone,
            decoration: const InputDecoration(
              labelText: 'Timezone (IANA)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _notifyPolicy,
            decoration: const InputDecoration(
              labelText: 'Notify policy',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'always', child: Text('Always')),
              DropdownMenuItem(value: 'never', child: Text('Never')),
              DropdownMenuItem(
                value: 'on_change',
                child: Text('Only when summary changes'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _notifyPolicy = value);
            },
          ),
          SwitchListTile(
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can also create or edit tasks by talking to Jarvis in the '
            'main chat once agent tools are available on the server.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
