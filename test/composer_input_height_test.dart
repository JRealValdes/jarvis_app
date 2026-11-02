import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/speech/composer_mic_controller.dart';
import 'package:jarvis_app/widgets/chat_composer.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  ChatComposer idleComposer(TextEditingController controller) {
    return ChatComposer(
      controller: controller,
      focusNode: FocusNode(),
      phase: ComposerMicPhase.idle,
      elapsed: Duration.zero,
      inputEnabled: true,
      onSend: () {},
      onMic: () {},
      onCancel: () {},
      onTogglePause: () {},
      onFinish: () {},
    );
  }

  testWidgets('composer input caps at composerMaxLines', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(host(idleComposer(controller)));

    final field = tester.widget<TextField>(find.byKey(const Key('composer_input')));
    expect(field.minLines, 1);
    expect(field.maxLines, composerMaxLines);
  });

  testWidgets('long draft stays within capped input height', (tester) async {
    final controller = TextEditingController(
      text: List.generate(20, (i) => 'Line $i of a long unsent draft').join('\n'),
    );
    await tester.pumpWidget(host(idleComposer(controller)));
    await tester.pumpAndSettle();

    final inputSize = tester.getSize(find.byKey(const Key('composer_input')));
    // Five lines of body text plus padding should stay well under unbounded growth.
    expect(inputSize.height, lessThan(200));
    expect(inputSize.height, greaterThan(40));
  });
}
