/// Resolve an assistant markdown image target against the Jarvis API origin.
///
/// Absolute `http(s)` URLs are returned as-is. Root-relative paths such as
/// `/images/{id}` are joined to [apiBaseUrl] (no trailing slash). Other schemes
/// and unresolvable relative paths return `null`.
String? resolveAssistantImageUrl(
  String raw, {
  String? apiBaseUrl,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (uri.hasScheme) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri.toString();
    }
    return null;
  }

  if (!trimmed.startsWith('/')) return null;

  final base = apiBaseUrl?.trim();
  if (base == null || base.isEmpty) return null;
  final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$normalized$trimmed';
}

/// Prefer `Content-Disposition` filename; otherwise derive from the URL / type.
String filenameForAssistantImage({
  required String url,
  String? contentDisposition,
  String? contentType,
}) {
  final fromHeader = filenameFromContentDisposition(contentDisposition);
  if (fromHeader != null) return fromHeader;

  final fromUrl = _extensionFromUrl(url);
  if (fromUrl != null) {
    final id = _idFromJarvisImagesPath(url) ?? 'jarvis-image';
    return '$id$fromUrl';
  }

  final fromType = _extensionFromContentType(contentType);
  final id = _idFromJarvisImagesPath(url) ?? 'jarvis-image';
  return '$id$fromType';
}

/// Basename without extension for [Gal.putImageBytes] `name`.
String gallerySaveName(String filename) {
  final base = filename.split(RegExp(r'[/\\]')).last;
  final dot = base.lastIndexOf('.');
  if (dot <= 0) return base.isEmpty ? 'jarvis-image' : base;
  return base.substring(0, dot);
}

String? filenameFromContentDisposition(String? header) {
  if (header == null || header.trim().isEmpty) return null;
  final star = RegExp(
    r"""filename\*\s*=\s*UTF-8''([^;]+)""",
    caseSensitive: false,
  ).firstMatch(header);
  if (star != null) {
    final raw = star.group(1)!.trim();
    try {
      final decoded = Uri.decodeComponent(raw);
      if (decoded.isNotEmpty) return decoded.split(RegExp(r'[/\\]')).last;
    } catch (_) {
      if (raw.isNotEmpty) return raw.split(RegExp(r'[/\\]')).last;
    }
  }
  final quoted = RegExp(
    r'''filename\s*=\s*"([^"]+)"''',
    caseSensitive: false,
  ).firstMatch(header);
  if (quoted != null) {
    final name = quoted.group(1)!.trim();
    if (name.isNotEmpty) return name.split(RegExp(r'[/\\]')).last;
  }
  final plain = RegExp(
    r'''filename\s*=\s*([^;]+)''',
    caseSensitive: false,
  ).firstMatch(header);
  if (plain != null) {
    final name = plain.group(1)!.trim().replaceAll('"', '');
    if (name.isNotEmpty) return name.split(RegExp(r'[/\\]')).last;
  }
  return null;
}

String? _idFromJarvisImagesPath(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments[segments.length - 2] == 'images') {
    final id = segments.last;
    if (id.isNotEmpty) return id;
  }
  return null;
}

String? _extensionFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final path = uri?.path ?? url;
  final lower = path.toLowerCase();
  for (final ext in const ['.jpg', '.jpeg', '.png', '.gif', '.webp']) {
    if (lower.endsWith(ext)) {
      return ext == '.jpeg' ? '.jpg' : ext;
    }
  }
  return null;
}

String _extensionFromContentType(String? contentType) {
  final type = (contentType ?? '').split(';').first.trim().toLowerCase();
  return switch (type) {
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    'image/jpeg' || 'image/jpg' => '.jpg',
    _ => '.jpg',
  };
}
