import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/images/assistant_image_url.dart';

void main() {
  group('resolveAssistantImageUrl', () {
    test('keeps absolute http(s) URLs', () {
      expect(
        resolveAssistantImageUrl(
          'https://api.example/images/abc',
          apiBaseUrl: 'http://ignored',
        ),
        'https://api.example/images/abc',
      );
      expect(
        resolveAssistantImageUrl('http://lan:8000/images/abc'),
        'http://lan:8000/images/abc',
      );
    });

    test('joins root-relative /images/{id} to the API origin', () {
      expect(
        resolveAssistantImageUrl(
          '/images/deadbeef',
          apiBaseUrl: 'http://192.168.1.10:8000',
        ),
        'http://192.168.1.10:8000/images/deadbeef',
      );
      expect(
        resolveAssistantImageUrl(
          '/images/deadbeef',
          apiBaseUrl: 'http://192.168.1.10:8000/',
        ),
        'http://192.168.1.10:8000/images/deadbeef',
      );
    });

    test('returns null when a relative path has no API origin', () {
      expect(resolveAssistantImageUrl('/images/abc'), isNull);
      expect(
        resolveAssistantImageUrl('/images/abc', apiBaseUrl: '  '),
        isNull,
      );
    });

    test('rejects non-http schemes and bare relatives', () {
      expect(resolveAssistantImageUrl('data:image/png;base64,xx'), isNull);
      expect(
        resolveAssistantImageUrl('images/abc', apiBaseUrl: 'http://x'),
        isNull,
      );
      expect(resolveAssistantImageUrl(''), isNull);
    });
  });

  group('filenameForAssistantImage', () {
    test('prefers Content-Disposition filename', () {
      expect(
        filenameForAssistantImage(
          url: 'http://x/images/deadbeef',
          contentDisposition: 'inline; filename="deadbeef.png"',
          contentType: 'image/jpeg',
        ),
        'deadbeef.png',
      );
    });

    test('falls back to Jarvis id plus content type', () {
      expect(
        filenameForAssistantImage(
          url: 'http://x/images/deadbeef',
          contentType: 'image/webp',
        ),
        'deadbeef.webp',
      );
    });

    test('uses a safe default when nothing else is known', () {
      expect(
        filenameForAssistantImage(url: 'https://cdn.example/pic'),
        'jarvis-image.jpg',
      );
    });
  });

  test('gallerySaveName strips the extension', () {
    expect(gallerySaveName('deadbeef.png'), 'deadbeef');
    expect(gallerySaveName('jarvis-image.jpg'), 'jarvis-image');
  });
}
