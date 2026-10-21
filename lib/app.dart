import 'package:flutter/material.dart';

import 'data/secure_store.dart';
import 'domain/models/jarvis_mode.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Jarvis App',
      home: JarvisBootGate(),
    );
  }
}

/// Mode-aware boot: local setup vs chat, or remote login vs chat.
class JarvisBootGate extends StatefulWidget {
  const JarvisBootGate({super.key});

  @override
  State<JarvisBootGate> createState() => _JarvisBootGateState();
}

class _JarvisBootGateState extends State<JarvisBootGate> {
  Widget _home = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final store = SecureStore();
    final mode = await store.getMode();

    if (mode == JarvisMode.local) {
      final ready = await store.isLocalConfigured();
      if (!mounted) return;
      setState(() {
        _home = ready ? const ChatScreen() : const SetupScreen();
      });
      return;
    }

    // Remote mode: Firebase + JWT.
    try {
      await FirebaseService.ensureInit();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _home = const LoginScreen();
      });
      return;
    }

    final auth = AuthService();
    final valid = await auth.validateToken();
    if (!valid) {
      await auth.logout();
      await store.deleteThreadId();
    }
    if (!mounted) return;
    setState(() {
      _home = valid ? const ChatScreen() : const LoginScreen();
    });
  }

  @override
  Widget build(BuildContext context) => _home;
}
