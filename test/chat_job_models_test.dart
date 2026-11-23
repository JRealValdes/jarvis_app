import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/domain/models/chat_job.dart';

void main() {
  test('ChatJob.fromJson accepts ask-async and poll shapes', () {
    final accepted = ChatJob.fromJson({
      'job_id': 'j1',
      'status': 'running',
      'thread_id': 'Alice',
    });
    expect(accepted.isRunning, isTrue);

    final done = ChatJob.fromJson({
      'job_id': 'j1',
      'status': 'done',
      'thread_id': 'Alice',
      'response': ['Hello'],
      'finished_at': '2024-01-01T00:00:00+00:00',
    });
    expect(done.isDone, isTrue);
    expect(done.response, ['Hello']);
  });
}
