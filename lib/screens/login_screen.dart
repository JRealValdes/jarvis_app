import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  void _onLogin() async {
    final ok = await _auth.login(_userCtrl.text, _passCtrl.text);

    if (ok) {
      final threadId = await StorageService.getThreadId();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(threadId: threadId)),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _userCtrl, decoration: InputDecoration(labelText: 'User')),
            TextField(controller: _passCtrl, decoration: InputDecoration(labelText: 'Pass'), obscureText: true),
            ElevatedButton(onPressed: _onLogin, child: Text('Login'))
          ],
        ),
      ),
    );
  }
}
