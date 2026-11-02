// Helpers for chat list scroll anchoring (newest messages / keyboard inset).

const double chatBottomScrollThreshold = 50;

/// Whether the list is pinned to the live (newest) end.
///
/// Reversed lists grow upward from offset 0; normal lists use [maxScrollExtent].
bool isChatNearBottom({
  required double pixels,
  required double maxScrollExtent,
  required bool reverse,
  double threshold = chatBottomScrollThreshold,
}) {
  if (reverse) {
    return pixels <= threshold;
  }
  return (maxScrollExtent - pixels).abs() <= threshold;
}

/// Scroll offset that shows the newest messages.
double chatBottomScrollOffset({
  required double maxScrollExtent,
  required bool reverse,
}) {
  return reverse ? 0.0 : maxScrollExtent;
}

/// Re-anchor to the newest messages after a keyboard inset change only when
/// the user was already following the live end.
bool shouldKeepBottomAnchorOnKeyboard({
  required bool wasAtBottom,
  required double previousBottomInset,
  required double nextBottomInset,
}) {
  if (!wasAtBottom) return false;
  return (nextBottomInset - previousBottomInset).abs() > 1.0;
}
