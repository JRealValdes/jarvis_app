import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/tools/calc_tool.dart';
import 'package:jarvis_app/domain/chat_state.dart';
import 'package:jarvis_app/domain/models/user_profile.dart';
import 'package:jarvis_app/domain/prompts.dart';

void main() {
  group('SafeCalculator', () {
    test('evaluates arithmetic with precedence', () {
      expect(SafeCalculator.evaluate('2 + 2 * 3'), 8);
      expect(SafeCalculator.evaluate('(2 + 2) * 3'), 12);
      expect(SafeCalculator.evaluate('10 / 4'), 2.5);
    });

    test('rejects invalid input', () {
      expect(() => SafeCalculator.evaluate('2 +'), throwsFormatException);
      expect(() => SafeCalculator.evaluate('import os'), throwsFormatException);
    });
  });

  group('CalculateTool', () {
    test('returns rounded float string', () async {
      final tool = CalculateTool();
      final result = await tool.execute({'expression': '1/3'});
      expect(result, '0.33');
    });
  });

  group('ChatState', () {
    test('welcome then starting then initialized', () {
      var state = ChatState.notInitialized;
      state = computeNextChatState(
        state,
        validUser: true,
        wasPreviouslyInvalid: false,
      );
      expect(state, ChatState.jarvisWelcomeMessage);

      state = computeNextChatState(
        state,
        validUser: true,
        wasPreviouslyInvalid: false,
      );
      expect(state, ChatState.startingChat);

      state = computeNextChatState(
        state,
        validUser: true,
        wasPreviouslyInvalid: false,
      );
      expect(state, ChatState.initialized);
    });
  });

  group('prompts', () {
    test('welcome uses jarvis name', () {
      const user = UserProfile(jarvisName: 'Tony', isFemale: false);
      expect(getWelcomeMessage(user), 'Welcome, Tony. How may I assist you today?');
      expect(
        buildBackgroundPrompt(validUser: true, user: user),
        contains("name 'Tony'"),
      );
      expect(
        buildBackgroundPrompt(validUser: true, user: user),
        contains('sir'),
      );
    });
  });
}
