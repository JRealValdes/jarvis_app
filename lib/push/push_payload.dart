/// Parsed FCM / local-notification data payload.
class PushPayload {
  const PushPayload({
    required this.type,
    this.taskId,
    this.jobId,
  });

  final String type;
  final String? taskId;
  final String? jobId;

  bool get isPeriodicTask => type == 'periodic_task' && (taskId ?? '').isNotEmpty;
  bool get isChatJob => type == 'chat_job' && (jobId ?? '').isNotEmpty;

  /// Parse string-keyed data maps from FCM or local notifications.
  static PushPayload? tryParse(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    final type = '${data['type'] ?? ''}'.trim();
    if (type.isEmpty) return null;
    return PushPayload(
      type: type,
      taskId: _stringOrNull(data['task_id']),
      jobId: _stringOrNull(data['job_id']),
    );
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
