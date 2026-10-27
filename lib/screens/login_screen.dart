import 'package:flutter/material.dart';

import '../agent/remote/endpoint.dart';
import '../data/secure_store.dart';
import '../agent/remote/auth_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _baseUrlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _store = SecureStore();
  final _auth = AuthService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUrl = await _store.getApiBaseUrl();
    final savedUser = await _store.getUsername();
    final savedPass = await _store.getPassword();
    if (!mounted) return;
    if (savedUrl != null) _baseUrlCtrl.text = savedUrl;
    if (savedUser != null) _userCtrl.text = savedUser;
    if (savedPass != null) _passCtrl.text = savedPass;
  }

  Future<void> _onLogin() async {
    final normalized = RemoteEndpoint.normalize(_baseUrlCtrl.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set a valid API base URL '
            '(e.g. http://192.168.x.x:8000 or http://100.x.y.z:8000)',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    await _store.setApiBaseUrl(normalized);
    _baseUrlCtrl.text = normalized;

    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    final ok = await _auth.login(username, password);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      await _store.setUsername(username);
      await _store.setPassword(password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote login — J.A.R.V.I.S.'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AutofillGroup(
          child: Column(
            children: [
              const Text(
                'Connects to your Jarvis FastAPI. On the home LAN use the Pi IP; '
                'off-LAN install Tailscale on phone and Pi (same tailnet) and use '
                'MagicDNS or a 100.x address — same port. '
                'For on-device chat without a server, switch to Local in Settings.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  hintText: RemoteEndpoint.urlFieldHint,
                  helperText: RemoteEndpoint.urlFieldHelper,
                  helperMaxLines: 3,
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: !_busy,
              ),
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: 'User'),
                autofillHints: const [AutofillHints.username],
                enabled: !_busy,
              ),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Pass'),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onLogin(),
                enabled: !_busy,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _onLogin,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
