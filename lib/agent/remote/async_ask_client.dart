import 'dart:async';

import '../../domain/chat_image.dart';
import '../../domain/models/chat_job.dart';
import 'remote_jarvis_api.dart';

/// Submit a long `/ask-async` turn and poll until done/failed.
class AsyncAskClient {
  AsyncAskClient(this._api, {this.pollInterval = const Duration(seconds: 2)});

  final RemoteJarvisApi _api;
  final Duration pollInterval;

  /// Start an async ask and wait for completion (or [timeout]).
  Future<ChatJob> askAndWait(
    String message, {
    required String modelName,
    List<ChatImage> images = const [],
    String? threadId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final accepted = await _api.askAsync(
      message,
      modelName: modelName,
      images: images,
      threadId: threadId,
    );
    final deadline = DateTime.now().add(timeout);
    var job = accepted;
    while (job.isRunning) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'Timed out waiting for job ${job.jobId}',
          timeout,
        );
      }
      await Future<void>.delayed(pollInterval);
      job = await _api.getJob(job.jobId);
    }
    return job;
  }
}
