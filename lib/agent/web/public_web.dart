import 'dart:convert';

import 'package:http/http.dart' as http;

import 'url_policy.dart';

const int defaultMaxSearchResults = 5;
const int hardMaxSearchResults = 10;
const int defaultFetchTop = 2;
const int hardMaxFetchTop = 3;
const int maxResponseBytes = 500000;
const int maxExtractedChars = 8000;

class WebSearchHit {
  const WebSearchHit({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;
}

class FetchedPage {
  const FetchedPage({
    required this.url,
    required this.title,
    required this.text,
  });

  final String url;
  final String title;
  final String text;
}

/// DuckDuckGo HTML search + public page fetch (no API key).
class PublicWebClient {
  PublicWebClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<WebSearchHit>> search(
    String query, {
    int maxResults = defaultMaxSearchResults,
  }) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Search query is empty.');
    }
    final limit = maxResults.clamp(1, hardMaxSearchResults);

    final uri = Uri.parse('https://html.duckduckgo.com/html/');
    final response = await _http
        .post(
          uri,
          headers: {
            'User-Agent': jarvisWebUserAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'q': cleaned},
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Search failed: HTTP ${response.statusCode}');
    }

    return _parseDuckDuckGoHtml(utf8.decode(response.bodyBytes), limit);
  }

  Future<FetchedPage> fetchPage(String url) async {
    final cleaned = assertFetchableUrl(url);
    final response = await _http
        .get(
          Uri.parse(cleaned),
          headers: {'User-Agent': jarvisWebUserAgent},
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Fetch failed: HTTP ${response.statusCode}');
    }

    var bytes = response.bodyBytes;
    if (bytes.length > maxResponseBytes) {
      bytes = bytes.sublist(0, maxResponseBytes);
    }
    final html = utf8.decode(bytes, allowMalformed: true);
    final title = _extractTitle(html);
    final text = _stripHtml(html);
    if (text.trim().isEmpty) {
      throw StateError('Could not extract readable text from $cleaned');
    }
    final clipped = text.length > maxExtractedChars
        ? text.substring(0, maxExtractedChars)
        : text;
    return FetchedPage(url: cleaned, title: title, text: clipped);
  }

  List<WebSearchHit> _parseDuckDuckGoHtml(String html, int limit) {
    final hits = <WebSearchHit>[];
    // result__a anchors; href may be /l/?uddg=<encoded>
    final linkRe = RegExp(
      r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRe = RegExp(
      r'class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</',
      caseSensitive: false,
      dotAll: true,
    );
    final snippets = snippetRe
        .allMatches(html)
        .map((m) => _stripHtml(m.group(1) ?? '').trim())
        .toList();

    var i = 0;
    for (final m in linkRe.allMatches(html)) {
      if (hits.length >= limit) break;
      final href = _resolveDuckDuckGoHref(m.group(1) ?? '');
      if (href == null) continue;
      final title = _stripHtml(m.group(2) ?? '').trim();
      final snippet = i < snippets.length ? snippets[i] : '';
      i += 1;
      hits.add(WebSearchHit(title: title, url: href, snippet: snippet));
    }
    return hits;
  }

  String? _resolveDuckDuckGoHref(String raw) {
    var href = raw.replaceAll('&amp;', '&').trim();
    if (href.isEmpty) return null;
    if (href.startsWith('//')) href = 'https:$href';
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    final uddg = uri.queryParameters['uddg'];
    if (uddg != null && uddg.isNotEmpty) {
      return Uri.decodeComponent(uddg);
    }
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri.toString();
    }
    return null;
  }

  String _extractTitle(String html) {
    final m = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return '';
    return _stripHtml(m.group(1) ?? '').trim();
  }

  String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }
}

String formatSearchResults(List<WebSearchHit> results) {
  if (results.isEmpty) return 'No search results.';
  final lines = <String>['## Search results'];
  for (var i = 0; i < results.length; i++) {
    final item = results[i];
    lines.add('${i + 1}. **${item.title.isEmpty ? '(no title)' : item.title}**');
    lines.add('   - URL: ${item.url}');
    if (item.snippet.isNotEmpty) {
      lines.add('   - Snippet: ${item.snippet}');
    }
  }
  return lines.join('\n');
}

String formatFetchedPage(FetchedPage page) {
  return '## Fetched page\n'
      '- Title: ${page.title.isEmpty ? '(no title)' : page.title}\n'
      '- URL: ${page.url}\n\n'
      '${page.text}\n\n'
      'Cite this URL when using facts from the page.';
}
