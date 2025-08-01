import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'session_manager_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final savedUser = await _storage.read(key: 'username');
    final savedPass = await _storage.read(key: 'password');

    if (savedUser != null) _userCtrl.text = savedUser;
    if (savedPass != null) _passCtrl.text = savedPass;
  }

  void _onLogin() async {
    final username = _userCtrl.text;
    final password = _passCtrl.text;

    final ok = await _auth.login(username, password);

    if (ok) {
      await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'password', value: password);

      final isAdmin = await _auth.isAdmin();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isAdmin ? SessionManagerScreen() : ChatScreen(),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to J.A.R.V.I.S. - v1.1.0')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: 'User'),
                autofillHints: const [AutofillHints.username],
              ),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Pass'),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onLogin(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _onLogin, child: const Text('Login')),
            ],
          ),
        ),
      ),
    );
  }
}
