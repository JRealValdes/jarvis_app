import 'package:url_launcher/url_launcher.dart';

/// Opens an external Markdown link (http, https, mailto).
///
/// Returns `false` when [href] is missing, has an unsupported scheme, or
/// launching fails. Never throws.
Future<bool> openMarkdownExternalLink(
  String? href, {
  Future<bool> Function(Uri uri)? launch,
}) async {
  if (href == null || href.trim().isEmpty) return false;

  final uri = Uri.tryParse(href.trim());
  if (uri == null || !uri.hasScheme) return false;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https' && scheme != 'mailto') {
    return false;
  }

  final doLaunch = launch ??
      ((Uri target) => launchUrl(target, mode: LaunchMode.externalApplication));

  try {
    return await doLaunch(uri);
  } catch (_) {
    return false;
  }
}
