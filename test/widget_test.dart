import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/app.dart';
import 'package:jarvis_app/screens/setup_screen.dart';

void main() {
  testWidgets('Boot gate settles without crashing when unconfigured',
      (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.pump(); // start async route
    await tester.pump(const Duration(milliseconds: 100));

    // Auto default may land on Setup, Login, or stay loading without platform plugins.
    final setup = find.byType(SetupScreen);
    final loading = find.byType(CircularProgressIndicator);
    expect(
      setup.evaluate().isNotEmpty || loading.evaluate().isNotEmpty,
      isTrue,
    );
  });
}
