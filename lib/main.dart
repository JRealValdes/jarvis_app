import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(JarvisApp());
}

// This widget is the root of your application.
class JarvisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis App',
      home: LoginScreen(),
    );
  }
}
