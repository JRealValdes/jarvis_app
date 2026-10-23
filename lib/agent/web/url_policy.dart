/// Public-web fetch policy (aligned with Python `infrastructure.web.policy`).
class UrlPolicyError implements Exception {
  UrlPolicyError(this.message);
  final String message;

  @override
  String toString() => message;
}

const String jarvisWebUserAgent =
    'JarvisBot/0.1 (+https://github.com/JRealValdes/jarvis_app; public-read only)';

/// Browser-like UA for DuckDuckGo HTML search only (JarvisBot is blocked).
const String jarvisSearchUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

const _blockedHostSuffixes = <String>[
  'glassdoor.com',
  'glassdoor.es',
  'glassdoor.co.uk',
  'glassdoor.ca',
  'glassdoor.de',
  'glassdoor.fr',
  'glassdoor.it',
  'glassdoor.nl',
  'glassdoor.ie',
  'glassdoor.com.au',
  'glassdoor.com.mx',
  'glassdoor.com.br',
  'glassdoor.co.in',
  'glassdoor.sg',
  'glassdoor.com.hk',
];

String normalizeHostname(String? hostname) {
  if (hostname == null) return '';
  var host = hostname.trim().toLowerCase().replaceAll(RegExp(r'\.$'), '');
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

bool isBlockedHost(String? hostname) {
  final host = normalizeHostname(hostname);
  if (host.isEmpty) return false;
  for (final suffix in _blockedHostSuffixes) {
    if (host == suffix || host.endsWith('.$suffix')) return true;
  }
  return false;
}

bool _isPrivateOrLocalHost(String host) {
  if (host == 'localhost' || host == '::1') return true;
  final ip = Uri.parse('http://$host').host;
  // IPv4 quick checks
  final parts = ip.split('.');
  if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
    final a = int.parse(parts[0]);
    final b = int.parse(parts[1]);
    if (a == 10) return true;
    if (a == 127) return true;
    if (a == 0) return true;
    if (a == 169 && b == 254) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
  }
  return false;
}

/// Returns a cleaned absolute http(s) URL or throws [UrlPolicyError].
String assertFetchableUrl(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw UrlPolicyError('Invalid URL: $url');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw UrlPolicyError('Only http/https URLs are allowed.');
  }
  if (isBlockedHost(uri.host)) {
    throw UrlPolicyError('Blocked host: ${uri.host}');
  }
  if (_isPrivateOrLocalHost(uri.host)) {
    throw UrlPolicyError('Private/local hosts are not allowed.');
  }
  return uri.toString();
}
