import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/widgets/markdown_external_link.dart';

void main() {
  test('rejects null, empty, and blank href', () async {
    expect(await openMarkdownExternalLink(null), isFalse);
    expect(await openMarkdownExternalLink(''), isFalse);
    expect(await openMarkdownExternalLink('   '), isFalse);
  });

  test('rejects unsupported schemes', () async {
    final launched = <Uri>[];
    Future<bool> launch(Uri uri) async {
      launched.add(uri);
      return true;
    }

    expect(
      await openMarkdownExternalLink('javascript:alert(1)', launch: launch),
      isFalse,
    );
    expect(
      await openMarkdownExternalLink('file:///tmp/x', launch: launch),
      isFalse,
    );
    expect(launched, isEmpty);
  });

  test('opens http, https, and mailto via launch callback', () async {
    final launched = <Uri>[];
    Future<bool> launch(Uri uri) async {
      launched.add(uri);
      return true;
    }

    expect(
      await openMarkdownExternalLink('https://example.com/path', launch: launch),
      isTrue,
    );
    expect(
      await openMarkdownExternalLink('http://example.com', launch: launch),
      isTrue,
    );
    expect(
      await openMarkdownExternalLink('mailto:jarvis@example.com', launch: launch),
      isTrue,
    );

    expect(launched.map((u) => u.toString()).toList(), [
      'https://example.com/path',
      'http://example.com',
      'mailto:jarvis@example.com',
    ]);
  });

  test('returns false when launch throws', () async {
    expect(
      await openMarkdownExternalLink(
        'https://example.com',
        launch: (_) async => throw StateError('no browser'),
      ),
      isFalse,
    );
  });

  test('returns false when launch reports failure', () async {
    expect(
      await openMarkdownExternalLink(
        'https://example.com',
        launch: (_) async => false,
      ),
      isFalse,
    );
  });
}
