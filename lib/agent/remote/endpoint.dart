import '../../config/app_config.dart';
import '../../data/secure_store.dart';

/// Resolves the Jarvis FastAPI base URL from operator Settings.
class RemoteEndpoint {
  RemoteEndpoint({SecureStore? secureStore})
      : _store = secureStore ?? SecureStore();

  final SecureStore _store;

  /// Normalize user/build input: trim, optional `http://`, no trailing slash.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return s;
  }

  Future<String?> resolve() async {
    return normalize(await _store.getApiBaseUrl());
  }

  Future<String> requireBaseUrl() async {
    final url = await resolve();
    if (url == null || url.isEmpty) {
      throw StateError(
        'Jarvis API base URL is missing. Set it in Settings (LAN IP or hostname).',
      );
    }
    return url;
  }

  /// Primary configured URL, then optional build-time LAN fallback (distinct).
  Future<List<String>> candidateBases() async {
    final primary = await requireBaseUrl();
    final out = <String>[primary];
    final fb = normalize(AppConfig.lanFallbackBaseUrl);
    if (fb != null && fb != primary) {
      out.add(fb);
    }
    return out;
  }
}
