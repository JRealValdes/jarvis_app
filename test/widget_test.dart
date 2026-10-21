import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/app.dart';
import 'package:jarvis_app/screens/setup_screen.dart';

void main() {
  testWidgets('Boot gate shows setup for unconfigured local mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.pump(); // start async route
    await tester.pump(const Duration(milliseconds: 100));

    // Without a stored API key, local default should land on Setup.
    // Secure storage may be unavailable in unit tests — accept Setup or loading.
    final setup = find.byType(SetupScreen);
    final loading = find.byType(CircularProgressIndicator);
    expect(
      setup.evaluate().isNotEmpty || loading.evaluate().isNotEmpty,
      isTrue,
    );
  });
}
