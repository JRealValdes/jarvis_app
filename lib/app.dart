import 'package:flutter/material.dart';

import 'data/local_credentials.dart';
import 'data/secure_store.dart';
import 'domain/models/jarvis_mode.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'agent/remote/auth_service.dart';
import 'agent/remote/firebase_service.dart';

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

/// Mode-aware boot: local setup vs chat, or remote login vs chat / offline.
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

    if (mode == JarvisMode.remote) {
      await _routeRemoteOnly();
      return;
    }

    // Auto: remote preferred, offline if unreachable + key/profile ready.
    await _routeAuto(store);
  }

  Future<void> _routeRemoteOnly() async {
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
    }
    if (!mounted) return;
    setState(() {
      _home = valid ? const ChatScreen() : const LoginScreen();
    });
  }

  Future<void> _routeAuto(SecureStore store) async {
    final local = LocalCredentials(store: store);
    final auth = AuthService(secureStore: store);
    final result = await auth.validateTokenDetailed();

    if (!mounted) return;

    switch (result) {
      case TokenValidationResult.valid:
        setState(() => _home = const ChatScreen());
        return;
      case TokenValidationResult.invalidAuth:
        await auth.logout();
        if (!mounted) return;
        setState(() => _home = const LoginScreen());
        return;
      case TokenValidationResult.noToken:
      case TokenValidationResult.unreachable:
        final ready = await local.isConfigured();
        if (!mounted) return;
        if (ready) {
          // Offline-capable (or will failover after login attempt in chat).
          setState(() => _home = const ChatScreen());
        } else if (result == TokenValidationResult.noToken) {
          // Prefer login when we simply have no JWT; Setup if user wants offline.
          setState(() => _home = const LoginScreen());
        } else {
          // Unreachable and no offline key — Setup with CTA for offline key.
          setState(() => _home = const SetupScreen());
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) => _home;
}
