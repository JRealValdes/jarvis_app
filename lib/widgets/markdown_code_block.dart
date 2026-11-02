import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Fence info string used by the backend for LinkedIn/recruiter reply drafts.
///
/// Copy works for every fenced block; this label is the stable handoff value.
const String proposedReplyFenceLanguage = 'text';

/// Copies [text] to the system clipboard. Never throws to callers that await it
/// with a try/catch around [Clipboard.setData] failures.
Future<void> copyMarkdownCodeToClipboard(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}

/// Fence body for display/copy: strip the single trailing newline the Markdown
/// parser usually keeps from the closing fence line.
String normalizeFenceCode(String raw) {
  if (raw.endsWith('\n')) return raw.substring(0, raw.length - 1);
  return raw;
}

/// Extracts the fence language from a `pre` element (`language-foo` on `code`).
String? fenceLanguageFromPreElement(md.Element element) {
  for (final node in element.children ?? const <md.Node>[]) {
    if (node is! md.Element || node.tag != 'code') continue;
    final className = node.attributes['class'];
    if (className == null || className.isEmpty) return null;
    final match = RegExp(r'language-(\S+)').firstMatch(className);
    return match?.group(1);
  }
  return null;
}

/// Fenced code block with a one-tap Copy control.
class MarkdownCodeBlock extends StatefulWidget {
  const MarkdownCodeBlock({
    required this.code,
    this.language,
    this.style,
    this.copyToClipboard,
    super.key,
  });

  static const copyButtonKeyPrefix = 'markdown_code_block_copy_';

  /// Raw fence body (no surrounding fences).
  final String code;

  /// Optional info string (e.g. `text`, `powershell`).
  final String? language;

  final TextStyle? style;

  /// Override clipboard write (tests). Defaults to [copyMarkdownCodeToClipboard].
  final Future<void> Function(String text)? copyToClipboard;

  Key get copyButtonKey => Key('$copyButtonKeyPrefix${code.hashCode}');

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  var _copied = false;
  var _copying = false;
  Timer? _copiedReset;

  @override
  void dispose() {
    _copiedReset?.cancel();
    super.dispose();
  }

  Future<void> _onCopy() async {
    if (_copying) return;
    setState(() => _copying = true);

    final messenger = ScaffoldMessenger.maybeOf(context);
    final copy = widget.copyToClipboard ?? copyMarkdownCodeToClipboard;

    try {
      await copy(widget.code);
      if (!mounted) return;
      _copiedReset?.cancel();
      setState(() {
        _copied = true;
        _copying = false;
      });
      messenger?.showSnackBar(
        const SnackBar(content: Text('Copied')),
      );
      _copiedReset = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _copying = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not copy to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language?.trim();
    final showLanguage = language != null && language.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
          child: Row(
            children: [
              if (showLanguage)
                Expanded(
                  child: Text(
                    language,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                key: widget.copyButtonKey,
                onPressed: _copying ? null : _onCopy,
                icon: Icon(
                  _copied ? Icons.check : Icons.copy_outlined,
                  size: 16,
                ),
                label: Text(_copied ? 'Copied' : 'Copy'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: Colors.black87,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Text(
            widget.code,
            style: widget.style ??
                const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.6,
                  color: Colors.black87,
                ),
          ),
        ),
      ],
    );
  }
}

/// Renders every Markdown `pre` (fenced code) with [MarkdownCodeBlock].
class MarkdownFencedCodeBlockBuilder extends MarkdownElementBuilder {
  MarkdownFencedCodeBlockBuilder({this.copyToClipboard});

  final Future<void> Function(String text)? copyToClipboard;

  @override
  bool isBlockElement() => true;

  /// flutter_markdown routes `pre` text through the custom builder's
  /// [visitText]. Returning a shrink keeps inlines non-empty so they flush
  /// cleanly; the real UI is built in [visitElementAfterWithContext].
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return const SizedBox.shrink();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return MarkdownCodeBlock(
      code: normalizeFenceCode(element.textContent),
      language: fenceLanguageFromPreElement(element),
      style: preferredStyle,
      copyToClipboard: copyToClipboard,
    );
  }
}
