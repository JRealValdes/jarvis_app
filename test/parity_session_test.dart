import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/domain/chat_state.dart';
import 'package:jarvis_app/domain/models/user_profile.dart';
import 'package:jarvis_app/domain/prompts.dart';

/// Golden-ish fixture mirroring Python welcome → starting transitions.
void main() {
  test('parity fixture: first two turns without LLM', () {
    const profile = UserProfile(jarvisName: 'Tony', isFemale: false);
    var state = ChatState.notInitialized;

    // Turn 1: "Hola" with valid local profile → welcome only.
    state = computeNextChatState(
      state,
      validUser: true,
      wasPreviouslyInvalid: false,
    );
    expect(state, ChatState.jarvisWelcomeMessage);
    final welcome = getWelcomeMessage(profile);
    expect(welcome, 'Welcome, Tony. How may I assist you today?');

    // Turn 2: advances to STARTING_CHAT (LLM would receive system + welcome + user).
    state = computeNextChatState(
      state,
      validUser: true,
      wasPreviouslyInvalid: false,
    );
    expect(state, ChatState.startingChat);
    final system = buildBackgroundPrompt(validUser: true, user: profile);
    expect(system, contains('Jarvis'));
    expect(system, contains('Tony'));

    state = computeNextChatState(
      state,
      validUser: true,
      wasPreviouslyInvalid: false,
    );
    expect(state, ChatState.initialized);
  });
}
