import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/session_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(JarvisApp());
}

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  final AuthService _auth = AuthService();

  Widget _defaultHome = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final valid = await _auth.validateToken();
    if (valid) {
      // final isAdmin = await _auth.isAdmin();
      // print('User is admin: $isAdmin');
      setState(() {
        // _defaultHome = isAdmin ? SessionManagerScreen() : ChatScreen();
        _defaultHome = ChatScreen();
      });
    } else {
      await _auth.logout();
      await StorageService.deleteThreadId();
      setState(() {
        _defaultHome = const LoginScreen();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis App',
      home: _defaultHome,
    );
  }
}
