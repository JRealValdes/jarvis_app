import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/openai/openai_client.dart';
import 'package:jarvis_app/agent/tools/calc_tool.dart';
import 'package:jarvis_app/agent/tools/datetime_tool.dart';
import 'package:jarvis_app/agent/tools/registry.dart';

void main() {
  test('OpenAI tool-calling loop executes calculate_tool then returns text', () async {
    var callCount = 0;
    final mock = MockClient((request) async {
      callCount++;
      if (callCount == 1) {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'calculate_tool',
                        'arguments': '{"expression":"2+2"}',
                      },
                    }
                  ],
                },
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'The answer is 4, sir.',
              },
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = OpenAiClient(
      apiKey: 'test-key',
      httpClient: mock,
    );

    final result = await client.completeWithTools(
      model: 'gpt-4o-mini',
      messages: [
        {'role': 'user', 'content': 'What is 2+2?'},
      ],
      tools: [CalculateTool(), CurrentDateTimeTool()],
    );

    expect(callCount, 2);
    expect(result.assistantTexts.any((t) => t.contains('4')), isTrue);
    expect(result.messages.any((m) => m['role'] == 'tool'), isTrue);
  });

  test('OpenAI tools expose expected function names', () {
    final calc = CalculateTool().toOpenAiTool();
    final dt = CurrentDateTimeTool().toOpenAiTool();
    expect(calc['function']['name'], 'calculate_tool');
    expect(dt['function']['name'], 'current_date_time_tool');
    final names = builtInTools().map((t) => t.name).toSet();
    expect(
      names,
      containsAll([
        'calculate_tool',
        'current_date_time_tool',
        'web_search_tool',
      ]),
    );
  });
}
