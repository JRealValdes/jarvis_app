import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/secure_store.dart';
import '../domain/models/user_profile.dart';

/// Shared form for first-time setup and Settings (local credentials).
class LocalSetupForm extends StatefulWidget {
  const LocalSetupForm({
    super.key,
    required this.onSaved,
    this.submitLabel = 'Save',
    this.showTitle = true,
  });

  final Future<void> Function() onSaved;
  final String submitLabel;
  final bool showTitle;

  @override
  State<LocalSetupForm> createState() => LocalSetupFormState();
}

class LocalSetupFormState extends State<LocalSetupForm> {
  final _store = SecureStore();
  final _keyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isFemale = false;
  String _model = AppConfig.defaultOpenAiModel;
  bool _obscureKey = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await _store.getOpenAiApiKey();
    final profile = await _store.getUserProfile();
    final model = await _store.getOpenAiModel();
    if (!mounted) return;
    setState(() {
      if (key != null) _keyCtrl.text = key;
      if (profile != null) {
        _nameCtrl.text = profile.jarvisName;
        _isFemale = profile.isFemale;
      }
      _model = model;
      _loading = false;
    });
  }

  Future<void> save() async {
    final key = _keyCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'OpenAI API key is required.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Jarvis name (how you are addressed) is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await _store.setOpenAiApiKey(key);
    await _store.setUserProfile(
      UserProfile(jarvisName: name, isFemale: _isFemale),
    );
    await _store.setOpenAiModel(_model);
    await widget.onSaved();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final children = <Widget>[
      if (widget.showTitle) ...[
        Text(
          'Local Jarvis setup',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your OpenAI key stays on this device (Android Keystore). '
          'Never commit it to source control. Intended for personal / sideload builds.',
        ),
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _keyCtrl,
        obscureText: _obscureKey,
        decoration: InputDecoration(
          labelText: 'OpenAI API key',
          suffixIcon: IconButton(
            icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureKey = !_obscureKey),
          ),
        ),
        autocorrect: false,
        enableSuggestions: false,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _model,
        decoration: const InputDecoration(labelText: 'Model'),
        items: AppConfig.openAiModelChoices
            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _model = v);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Jarvis name (how Jarvis addresses you)',
          hintText: 'e.g. Tony',
        ),
        textCapitalization: TextCapitalization.words,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text("Formal address: ma'am"),
        subtitle: Text(_isFemale ? "Uses ma'am" : 'Uses sir'),
        value: _isFemale,
        onChanged: (v) => setState(() => _isFemale = v),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _saving ? null : save,
        child: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.submitLabel),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
