import 'package:flutter/material.dart';

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
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUser = await _store.getUsername();
    final savedPass = await _store.getPassword();
    if (!mounted) return;
    if (savedUser != null) _userCtrl.text = savedUser;
    if (savedPass != null) _passCtrl.text = savedPass;
  }

  Future<void> _onLogin() async {
    setState(() => _busy = true);
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
                'Connects to your home FastAPI via the Firebase-published URL. '
                'For on-device chat without a PC, switch to Local in Settings.',
              ),
              const SizedBox(height: 16),
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
