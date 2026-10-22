import '../../config/app_config.dart';
import '../../data/secure_store.dart';

/// Resolves the Jarvis FastAPI base URL from operator Settings (not Firebase).
class RemoteEndpoint {
  RemoteEndpoint({SecureStore? secureStore})
      : _store = secureStore ?? SecureStore();

  final SecureStore _store;
  String? _cached;

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

  Future<String?> resolve({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached;
    final stored = await _store.getApiBaseUrl();
    _cached = normalize(stored);
    return _cached;
  }

  Future<String> requireBaseUrl({bool forceRefresh = false}) async {
    final url = await resolve(forceRefresh: forceRefresh);
    if (url == null || url.isEmpty) {
      throw StateError(
        'Jarvis API base URL is missing. Set it in Settings (LAN IP or hostname).',
      );
    }
    return url;
  }

  /// Parametrizable LAN fallback (`JARVIS_LAN_FALLBACK_URL`), if distinct.
  Future<String?> fallbackBaseUrl() async {
    final primary = await resolve();
    final fb = normalize(AppConfig.lanFallbackBaseUrl);
    if (fb == null || fb.isEmpty) return null;
    if (primary != null && primary == fb) return null;
    return fb;
  }

  void invalidateCache() {
    _cached = null;
  }
}
