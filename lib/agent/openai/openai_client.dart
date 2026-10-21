import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../tools/tool.dart';

/// Thin OpenAI Chat Completions client with tool-calling loop.
class OpenAiClient {
  OpenAiClient({
    required this.apiKey,
    http.Client? httpClient,
    this.baseUrl = AppConfig.openAiChatCompletionsUrl,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  /// Runs chat completions, executing [tools] until the model returns text.
  Future<OpenAiTurnResult> completeWithTools({
    required String model,
    required List<Map<String, dynamic>> messages,
    required List<JarvisTool> tools,
    double temperature = 0,
    int maxToolRounds = 8,
  }) async {
    final working = List<Map<String, dynamic>>.from(messages);
    final registry = {for (final t in tools) t.name: t};
    final assistantTexts = <String>[];

    for (var round = 0; round < maxToolRounds; round++) {
      final body = <String, dynamic>{
        'model': AppConfig.resolveOpenAiModelId(model),
        'temperature': temperature,
        'messages': working,
      };
      if (tools.isNotEmpty) {
        body['tools'] = tools.map((t) => t.toOpenAiTool()).toList();
      }

      final response = await _http.post(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiException(
          _statusMessage(response.statusCode, response.body),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw OpenAiException('OpenAI returned no choices');
      }
      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      working.add(Map<String, dynamic>.from(message));

      if (toolCalls == null || toolCalls.isEmpty) {
        final content = message['content']?.toString() ?? '';
        if (content.trim().isNotEmpty) {
          assistantTexts.add(content);
        }
        return OpenAiTurnResult(
          assistantTexts: assistantTexts.isEmpty
              ? ["I'm sorry, sir. I have no response for your request."]
              : assistantTexts,
          messages: working,
        );
      }

      for (final rawCall in toolCalls) {
        final call = rawCall as Map<String, dynamic>;
        final id = call['id']?.toString() ?? '';
        final fn = call['function'] as Map<String, dynamic>? ?? {};
        final name = fn['name']?.toString() ?? '';
        final argsRaw = fn['arguments']?.toString() ?? '{}';
        Map<String, dynamic> args;
        try {
          args = jsonDecode(argsRaw) as Map<String, dynamic>;
        } catch (_) {
          args = {};
        }

        final tool = registry[name];
        String result;
        if (tool == null) {
          result = 'Unknown tool: $name';
        } else {
          try {
            result = await tool.execute(args);
          } catch (e) {
            result = e.toString();
          }
        }

        // Surface tool invocation in UI-style text (parity with Python history).
        assistantTexts.add('_Calling tool: `$name`_');

        working.add({
          'role': 'tool',
          'tool_call_id': id,
          'content': result,
        });
      }
    }

    throw OpenAiException('Tool loop exceeded $maxToolRounds rounds');
  }

  static String _statusMessage(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Invalid OpenAI API key (401). Open Settings and paste a valid key.';
      case 429:
        return 'OpenAI rate limit exceeded (429). Try again shortly.';
      case 403:
        return 'OpenAI refused the request (403). Check key permissions and billing.';
      default:
        return 'OpenAI error $statusCode: ${_safeErrorBody(body)}';
    }
  }

  static String _safeErrorBody(String body) {
    // Never echo API keys; truncate raw body for diagnostics.
    if (body.length > 400) return '${body.substring(0, 400)}…';
    return body;
  }
}

class OpenAiTurnResult {
  const OpenAiTurnResult({
    required this.assistantTexts,
    required this.messages,
  });

  final List<String> assistantTexts;
  final List<Map<String, dynamic>> messages;
}

class OpenAiException implements Exception {
  OpenAiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
