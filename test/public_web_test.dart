import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/web/public_web.dart';
import 'package:jarvis_app/agent/web/url_policy.dart';

void main() {
  group('PublicWebClient.search', () {
    test('parses result__a hits with search UA', () async {
      late http.BaseRequest seen;
      final client = MockClient((request) async {
        seen = request;
        const html = '''
<a class="result__a" href="https://example.com/a">Alpha</a>
<a class="result__snippet">snip a</a>
<a class="result__a" href="/l/?uddg=https%3A%2F%2Fexample.com%2Fb">Beta</a>
<span class="result__snippet">snip b</span>
''';
        return http.Response(html, 200);
      });

      final hits = await PublicWebClient(httpClient: client).search('q', maxResults: 5);
      expect(seen.headers['user-agent'], jarvisSearchUserAgent);
      expect(hits, hasLength(2));
      expect(hits[0].title, 'Alpha');
      expect(hits[0].url, 'https://example.com/a');
      expect(hits[1].url, 'https://example.com/b');
    });

    test('empty / challenge page throws clear StateError', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><title>DuckDuckGo</title><body>anomaly challenge</body></html>',
          202,
        );
      });

      expect(
        () => PublicWebClient(httpClient: client).search('q'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('blocked or empty'),
          ),
        ),
      );
    });
  });

  group('PublicWebClient.fetchPage', () {
    test('uses JarvisBot UA', () async {
      late http.BaseRequest seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          '<html><title>Hi</title><body><p>Hello world page text</p></body></html>',
          200,
        );
      });

      final page = await PublicWebClient(httpClient: client)
          .fetchPage('https://example.com/x');
      expect(seen.headers['user-agent'], jarvisWebUserAgent);
      expect(page.title, 'Hi');
      expect(page.text, contains('Hello world'));
    });
  });
}
