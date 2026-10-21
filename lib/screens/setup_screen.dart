import 'package:flutter/material.dart';

import '../app.dart';
import '../data/secure_store.dart';
import '../domain/models/jarvis_mode.dart';
import '../widgets/local_setup_form.dart';
import 'chat_screen.dart';

/// First-run local configuration (required before chat in local mode).
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup J.A.R.V.I.S.'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await SecureStore().setMode(JarvisMode.remote);
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const JarvisBootGate()),
                (_) => false,
              );
            },
            child: const Text('Use remote'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LocalSetupForm(
            submitLabel: 'Continue to chat',
            onSaved: () async {
              await SecureStore().setMode(JarvisMode.local);
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
        ),
      ),
    );
  }
}
