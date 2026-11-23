/// Async chat job status from `GET /jobs/{id}`.
class ChatJob {
  const ChatJob({
    required this.jobId,
    required this.status,
    required this.threadId,
    this.response,
    this.error,
    this.createdAt,
    this.updatedAt,
    this.finishedAt,
  });

  final String jobId;
  final String status;
  final String threadId;
  final List<String>? response;
  final String? error;
  final String? createdAt;
  final String? updatedAt;
  final String? finishedAt;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';

  factory ChatJob.fromJson(Map<String, dynamic> json) {
    final raw = json['response'];
    return ChatJob(
      jobId: (json['job_id'] ?? json['id']) as String,
      status: json['status'] as String? ?? 'running',
      threadId: json['thread_id'] as String? ?? '',
      response: raw is List ? raw.map((e) => '$e').toList() : null,
      error: json['error'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      finishedAt: json['finished_at'] as String?,
    );
  }
}
