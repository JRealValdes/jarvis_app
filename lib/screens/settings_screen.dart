import 'package:flutter/material.dart';

import '../agent/backend_factory.dart';
import '../app.dart';
import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import '../agent/remote/auth_service.dart';
import '../widgets/local_setup_form.dart';
import 'login_screen.dart';

/// Control plane: execution mode, local credentials, remote session.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = SecureStore();
  final _auth = AuthService();
  JarvisMode _mode = JarvisMode.auto;
  String? _username;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _store.getMode();
    final user = await _store.getUsername();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _username = user;
      _loading = false;
    });
  }

  Future<void> _setMode(JarvisMode mode) async {
    final previous = _mode;
    await _store.setMode(mode);
    setState(() => _mode = mode);

    final leavingLocal = previous == JarvisMode.local;
    final enteringRemoteish =
        mode == JarvisMode.remote || mode == JarvisMode.auto;
    final enteringLocal = mode == JarvisMode.local;
    final leavingRemoteish =
        previous == JarvisMode.remote || previous == JarvisMode.auto;

    if (enteringRemoteish && leavingLocal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == JarvisMode.auto
                ? 'Auto prefers the server; offline OpenAI is ephemeral and not saved.'
                : 'Remote mode uses a separate server history. Local chats stay on device.',
          ),
        ),
      );
      if (mode == JarvisMode.remote) {
        final valid = await _auth.validateToken();
        if (!mounted) return;
        if (!valid) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
          return;
        }
      }
    }

    if (enteringLocal && leavingRemoteish) {
      final ready = await _store.isLocalConfigured();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Local-only mode uses on-device history. Remote chats stay on the server.',
          ),
        ),
      );
      if (!ready) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const JarvisBootGate()),
          (_) => false,
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JarvisBootGate()),
      (_) => false,
    );
  }

  Future<void> _logoutRemote() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() => _username = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Remote session cleared.')),
    );
  }

  Future<void> _clearLocalChat() async {
    final backend = await BackendFactory(secureStore: _store).create();
    await backend.resetSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local conversation cleared.')),
    );
  }

  Future<void> _clearApiKey() async {
    await _store.clearOpenAiApiKey();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OpenAI API key removed from this device.')),
    );
  }

  bool get _showLocalConfig =>
      _mode == JarvisMode.local || _mode == JarvisMode.auto;

  bool get _showRemoteSession =>
      _mode == JarvisMode.remote || _mode == JarvisMode.auto;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Execution mode'),
            subtitle: Text(
              'Auto prefers Jarvis Server, then on-device OpenAI if unreachable. '
              'Local-only and Remote-only disable failover.',
            ),
          ),
          RadioGroup<JarvisMode>(
            groupValue: _mode,
            onChanged: (mode) {
              if (mode != null) _setMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<JarvisMode>(
                  title: Text('Auto (remote preferred)'),
                  subtitle: Text(
                    'Default — offline failover when the server is down',
                  ),
                  value: JarvisMode.auto,
                ),
                RadioListTile<JarvisMode>(
                  title: Text('Local only'),
                  subtitle: Text('On-device OpenAI with disk history'),
                  value: JarvisMode.local,
                ),
                RadioListTile<JarvisMode>(
                  title: Text('Remote only'),
                  subtitle: Text('Requires reachable Jarvis FastAPI'),
                  value: JarvisMode.remote,
                ),
              ],
            ),
          ),
          const Divider(),
          if (_showLocalConfig) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'OpenAI (local / offline)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LocalSetupForm(
                showTitle: false,
                submitLabel: 'Save local settings',
                onSaved: () async {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local settings saved.')),
                  );
                },
              ),
            ),
            if (_mode == JarvisMode.local)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear local conversation'),
                onTap: _clearLocalChat,
              ),
            ListTile(
              leading: const Icon(Icons.key_off),
              title: const Text('Remove stored OpenAI API key'),
              onTap: _clearApiKey,
            ),
          ],
          if (_showRemoteSession) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Remote session',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(
                _username != null
                    ? 'Logged in as $_username'
                    : 'Not logged in',
              ),
              subtitle: const Text(
                'Firebase provides the API base URL. Home PC/tunnel must be up.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Remote login'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out remote'),
              onTap: _logoutRemote,
            ),
          ],
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Histories are separate: switching modes does not merge chats. '
              'Offline (Auto failover) turns are ephemeral and cleared on restart. '
              'Do not redistribute APKs that contain someone else’s API key.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
