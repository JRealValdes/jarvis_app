import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Rich markdown styles for assistant chat bubbles.
///
/// Tuned for grey assistant bubbles: clear heading hierarchy, readable lists,
/// GFM tables with horizontal scroll when wide, and contrasted fenced code.
///
/// Inline and fenced `code` share one [MarkdownStyleSheet.code] style in
/// flutter_markdown, so fenced blocks use a light elevated surface (not a dark
/// theme) so monospace stays readable in both places.
MarkdownStyleSheet assistantMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final base = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
  final baseSize = base.fontSize ?? 14;

  final tableBorderColor = Colors.grey.shade600;
  final inlineCodeBg = Colors.black.withValues(alpha: 0.08);

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    pPadding: const EdgeInsets.only(bottom: 2),
    blockSpacing: 10,
    strong: base.copyWith(fontWeight: FontWeight.w700),
    em: base.copyWith(fontStyle: FontStyle.italic),
    h1: base.copyWith(
      fontSize: baseSize + 6,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    h1Padding: const EdgeInsets.only(top: 10, bottom: 6),
    h2: base.copyWith(
      fontSize: baseSize + 4,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
    h3: base.copyWith(
      fontSize: baseSize + 2,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    h3Padding: const EdgeInsets.only(top: 6, bottom: 3),
    h4: base.copyWith(
      fontSize: baseSize + 1,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    h4Padding: const EdgeInsets.only(top: 4, bottom: 2),
    h5: base.copyWith(fontWeight: FontWeight.w600, height: 1.3),
    h5Padding: const EdgeInsets.only(top: 4, bottom: 2),
    h6: base.copyWith(fontWeight: FontWeight.w600, height: 1.3),
    h6Padding: const EdgeInsets.only(top: 2, bottom: 2),
    listIndent: 28,
    listBullet: base.copyWith(fontWeight: FontWeight.w600),
    listBulletPadding: const EdgeInsets.only(right: 6),
    code: base.copyWith(
      fontFamily: 'monospace',
      fontSize: baseSize * 0.9,
      backgroundColor: inlineCodeBg,
      color: Colors.black87,
    ),
    codeblockPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    codeblockDecoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade500),
    ),
    tableHead: base.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: baseSize * 0.95,
    ),
    tableBody: base.copyWith(fontSize: baseSize * 0.95),
    tableHeadAlign: TextAlign.left,
    tableBorder: TableBorder.all(color: tableBorderColor, width: 1),
    // Fixed width enables horizontal scroll for wide GFM tables
    // (flutter_markdown ≥ 0.7.3).
    tableColumnWidth: const FixedColumnWidth(112),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    tableCellsDecoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.45),
    ),
    blockquote: base.copyWith(color: Colors.black87),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
    blockquoteDecoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.35),
      border: Border(
        left: BorderSide(color: Colors.grey.shade700, width: 3),
      ),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(width: 1.5, color: Colors.grey.shade600),
      ),
    ),
  );
}
