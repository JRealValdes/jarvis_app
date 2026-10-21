import '../web/public_web.dart';
import '../web/url_policy.dart';
import 'tool.dart';

/// Public web search + page read (DuckDuckGo; no API key).
class WebSearchTool extends JarvisTool {
  WebSearchTool({PublicWebClient? client}) : _client = client ?? PublicWebClient();

  final PublicWebClient _client;

  @override
  String get name => 'web_search_tool';

  @override
  String get description =>
      'Search the public web and/or read the text of a public page. '
      'Use for current information (company, product, version, season, news). '
      'Pass a search query, a URL, or both. Prefer fetched page text over snippets. '
      'Public http(s) only; no login-gated sites (e.g. Glassdoor).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Optional web search query',
          },
          'url': {
            'type': 'string',
            'description': 'Optional absolute http(s) URL to fetch and read',
          },
          'max_results': {
            'type': 'integer',
            'description': 'Search hit count (default 5, max 10)',
          },
          'fetch_top': {
            'type': 'integer',
            'description':
                'After search, fetch readable text from up to this many hit URLs '
                    '(default 2, max 3; 0 for snippets only)',
          },
        },
        'additionalProperties': false,
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final query = (arguments['query']?.toString() ?? '').trim();
    final url = (arguments['url']?.toString() ?? '').trim();
    final maxResults = _asInt(arguments['max_results'], defaultMaxSearchResults)
        .clamp(1, hardMaxSearchResults);
    final fetchTop = _asInt(arguments['fetch_top'], defaultFetchTop)
        .clamp(0, hardMaxFetchTop);

    if (query.isEmpty && url.isEmpty) {
      return 'Provide a search query and/or a public http(s) URL. '
          "Example: query='Acme Corp engineering blog', "
          "or url='https://example.com/about'.";
    }

    final sections = <String>[];
    try {
      if (query.isNotEmpty) {
        final results = await _client.search(query, maxResults: maxResults);
        sections.add(formatSearchResults(results));
        sections.add(
          'Snippets can be stale. Prefer facts from Fetched page '
          'sections below. Prefer official sites and the newest dated '
          'sources. If sources conflict, say so and cite URLs. '
          'Do not fetch Glassdoor or other blocked job boards.',
        );
        var success = 0;
        for (final hit in results) {
          if (success >= fetchTop) break;
          try {
            final page = await _client.fetchPage(hit.url);
            sections.add(formatFetchedPage(page));
            success += 1;
          } on UrlPolicyError catch (e) {
            sections.add('## Skipped page\n- URL: ${hit.url}\n- Reason: $e');
          } catch (e) {
            sections.add('## Skipped page\n- URL: ${hit.url}\n- Reason: $e');
          }
        }
      }
      if (url.isNotEmpty) {
        final page = await _client.fetchPage(url);
        sections.add(formatFetchedPage(page));
      }
    } on UrlPolicyError catch (e) {
      return 'Blocked by public-web policy: $e';
    } catch (e) {
      return 'Web lookup failed: $e';
    }

    return sections.join('\n\n');
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
