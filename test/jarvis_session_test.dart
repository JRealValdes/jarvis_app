import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/openai/openai_client.dart';
import 'package:jarvis_app/agent/session/jarvis_session.dart';
import 'package:jarvis_app/agent/tools/registry.dart';
import 'package:jarvis_app/domain/chat_state.dart';
import 'package:jarvis_app/domain/models/user_profile.dart';

void main() {
  const profile = UserProfile(jarvisName: 'Tony', isFemale: false);

  OpenAiClient clientThatReplies(String text) {
    final mock = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': text},
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    return OpenAiClient(apiKey: 'test', httpClient: mock);
  }

  test('JarvisSession welcome then LLM turn advances to initialized', () async {
    final session = JarvisSession(
      threadId: 'local',
      profile: profile,
      openAi: clientThatReplies('At your service, Tony.'),
      tools: builtInTools(),
      model: 'gpt-4o-mini',
    );

    final welcome = await session.ask('Hello');
    expect(welcome.single, 'Welcome, Tony. How may I assist you today?');
    expect(session.chatState, ChatState.jarvisWelcomeMessage);

    final reply = await session.ask('What time is it?');
    expect(reply.single, contains('Tony'));
    expect(session.chatState, ChatState.startingChat);
    expect(session.llmMessages, isNotEmpty);

    final again = await session.ask('Thanks');
    expect(again, isNotEmpty);
    expect(session.chatState, ChatState.initialized);
  });
}
