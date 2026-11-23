/// Periodic task definition + latest run (FastAPI `/tasks`).
class PeriodicTask {
  const PeriodicTask({
    required this.id,
    required this.title,
    required this.instruction,
    required this.schedule,
    required this.timezone,
    required this.notifyPolicy,
    required this.enabled,
    required this.threadId,
    required this.nextResetBanner,
    this.nextRunAt,
    this.nextResetAt,
    this.latestRun,
  });

  final String id;
  final String title;
  final String instruction;
  final Map<String, dynamic> schedule;
  final String timezone;
  final String notifyPolicy;
  final bool enabled;
  final String threadId;
  final String nextResetBanner;
  final String? nextRunAt;
  final String? nextResetAt;
  final PeriodicTaskRun? latestRun;

  factory PeriodicTask.fromJson(Map<String, dynamic> json) {
    final run = json['latest_run'];
    return PeriodicTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      schedule: Map<String, dynamic>.from(json['schedule'] as Map? ?? {}),
      timezone: json['timezone'] as String? ?? 'UTC',
      notifyPolicy: json['notify_policy'] as String? ?? 'always',
      enabled: json['enabled'] == true,
      threadId: json['thread_id'] as String? ?? '',
      nextResetBanner: json['next_reset_banner'] as String? ??
          'This conversation resets on the next scheduled run.',
      nextRunAt: json['next_run_at'] as String?,
      nextResetAt: json['next_reset_at'] as String?,
      latestRun: run is Map
          ? PeriodicTaskRun.fromJson(Map<String, dynamic>.from(run))
          : null,
    );
  }

  String get scheduleLabel {
    final days = schedule['days_of_week'];
    final time = schedule['time'] as String? ?? '';
    final dayText = days is List ? days.join(', ') : '';
    return '$dayText @ $time ($timezone)';
  }

  String get statusSubtitle {
    final run = latestRun;
    if (run == null) return 'Never run';
    if (run.status == 'failed') {
      return 'Failed: ${run.summary ?? run.error ?? 'unknown error'}';
    }
    return run.summary?.isNotEmpty == true
        ? run.summary!
        : 'Last run: ${run.status}';
  }
}

/// Metadata for one task run.
class PeriodicTaskRun {
  const PeriodicTaskRun({
    required this.id,
    required this.taskId,
    required this.status,
    required this.pushSent,
    this.startedAt,
    this.finishedAt,
    this.summary,
    this.error,
  });

  final String id;
  final String taskId;
  final String status;
  final bool pushSent;
  final String? startedAt;
  final String? finishedAt;
  final String? summary;
  final String? error;

  factory PeriodicTaskRun.fromJson(Map<String, dynamic> json) {
    return PeriodicTaskRun(
      id: json['id'] as String,
      taskId: json['task_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pushSent: json['push_sent'] == true,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      summary: json['summary'] as String?,
      error: json['error'] as String?,
    );
  }
}
