import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/openai/openai_client.dart';
import 'package:jarvis_app/agent/openai/openai_errors.dart';
import 'package:jarvis_app/agent/web/url_policy.dart';

void main() {
  group('url policy', () {
    test('allows public https', () {
      expect(
        assertFetchableUrl('https://example.com/path'),
        'https://example.com/path',
      );
    });

    test('blocks glassdoor and localhost', () {
      expect(
        () => assertFetchableUrl('https://www.glassdoor.com/Jobs'),
        throwsA(isA<UrlPolicyError>()),
      );
      expect(
        () => assertFetchableUrl('http://127.0.0.1/secret'),
        throwsA(isA<UrlPolicyError>()),
      );
      expect(
        () => assertFetchableUrl('http://192.168.1.1/'),
        throwsA(isA<UrlPolicyError>()),
      );
    });
  });

  group('describeOpenAiError', () {
    test('maps 401 and 429', () {
      expect(
        describeOpenAiError(OpenAiException('x', statusCode: 401)),
        contains('Invalid OpenAI API key'),
      );
      expect(
        describeOpenAiError(OpenAiException('x', statusCode: 429)),
        contains('rate limit'),
      );
    });

    test('maps missing key StateError', () {
      expect(
        describeOpenAiError(
          StateError('OpenAI API key is missing. Open Settings and paste your key.'),
        ),
        contains('API key is missing'),
      );
    });
  });
}
