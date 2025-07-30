import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  void _onLogin() async {
    final ok = await _auth.login(_userCtrl.text, _passCtrl.text);
    if (ok) {
      Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
    } else {
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
