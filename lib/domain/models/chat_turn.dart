/// One turn in the conversation history shown in the UI / returned by backends.
class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.content,
  });

  /// `user`, `assistant`, or `system` (system is usually filtered in UI).
  final String role;
  final String content;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  factory ChatTurn.fromJson(Map<String, dynamic> json) {
    return ChatTurn(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
    );
  }
}
