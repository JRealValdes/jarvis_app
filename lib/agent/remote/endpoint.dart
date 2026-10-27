import '../../config/app_config.dart';
import '../../data/secure_store.dart';

/// Resolves the Jarvis FastAPI base URL from operator Settings.
class RemoteEndpoint {
  RemoteEndpoint({SecureStore? secureStore})
      : _store = secureStore ?? SecureStore();

  final SecureStore _store;

  /// Hint for the API base URL field (LAN or Tailscale).
  static const urlFieldHint = 'http://192.168.x.x:8000 or http://100.x.y.z:8000';

  /// Helper under Settings / Login base URL fields.
  static const urlFieldHelper =
      'Home LAN IP, or Tailscale MagicDNS / 100.x (same port). '
      'Install the Tailscale app on the phone; no Firebase or quick tunnels.';

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
        'Jarvis API base URL is missing. Set it in Settings '
        '(LAN IP or Tailscale MagicDNS / 100.x).',
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
