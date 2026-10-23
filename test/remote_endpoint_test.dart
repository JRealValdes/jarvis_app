import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/remote/endpoint.dart';
import 'package:jarvis_app/config/app_config.dart';

void main() {
  group('RemoteEndpoint.normalize', () {
    test('trims and strips trailing slash', () {
      expect(
        RemoteEndpoint.normalize('  http://192.168.1.10:8000/  '),
        'http://192.168.1.10:8000',
      );
    });

    test('adds http scheme when missing', () {
      expect(
        RemoteEndpoint.normalize('jarvis-raspberry.local:8000'),
        'http://jarvis-raspberry.local:8000',
      );
    });

    test('rejects empty and non-http schemes', () {
      expect(RemoteEndpoint.normalize(''), isNull);
      expect(RemoteEndpoint.normalize('   '), isNull);
      expect(RemoteEndpoint.normalize('ftp://host'), isNull);
      expect(RemoteEndpoint.normalize(null), isNull);
    });
  });

  group('LAN fallback config', () {
    test('default dart-define example is the Pi mDNS URL', () {
      expect(
        AppConfig.lanFallbackBaseUrl,
        'http://jarvis-raspberry.local:8000',
      );
      expect(AppConfig.lanFallbackTimeout, const Duration(seconds: 2));
    });
  });
}
