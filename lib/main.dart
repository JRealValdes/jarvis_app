import 'package:flutter/material.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is initialized lazily only when remote mode needs it.
  runApp(const JarvisApp());
}
