import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/remote/remote_cache_parsing.dart';

void main() {
  group('parseCacheSessionEntry', () {
    test('parses Python str(tuple) with quotes', () {
      expect(
        parseCacheSessionEntry("('GPT_4O_MINI', 'jose')"),
        ('GPT_4O_MINI', 'jose'),
      );
    });

    test('parses loose comma form', () {
      expect(
        parseCacheSessionEntry('GPT_3_5, thread-a'),
        ('GPT_3_5', 'thread-a'),
      );
    });

    test('returns null for empty junk', () {
      expect(parseCacheSessionEntry('   '), isNull);
    });
  });

  test('parseCacheSessionList drops nulls', () {
    final parsed = parseCacheSessionList([
      "('GPT_4O_MINI', 'a')",
      '',
      "('GPT_3_5', 'b')",
    ]);
    expect(parsed, [('GPT_4O_MINI', 'a'), ('GPT_3_5', 'b')]);
  });
}
