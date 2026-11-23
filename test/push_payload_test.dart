import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/push/push_payload.dart';

void main() {
  test('PushPayload.tryParse routes task and job types', () {
    final task = PushPayload.tryParse({
      'type': 'periodic_task',
      'task_id': 'abc',
    });
    expect(task?.isPeriodicTask, isTrue);
    expect(task?.taskId, 'abc');

    final job = PushPayload.tryParse({
      'type': 'chat_job',
      'job_id': 'job-1',
    });
    expect(job?.isChatJob, isTrue);

    expect(PushPayload.tryParse({}), isNull);
    expect(PushPayload.tryParse({'type': 'other'}), isNotNull);
    expect(PushPayload.tryParse({'type': 'other'})!.isPeriodicTask, isFalse);
  });
}
