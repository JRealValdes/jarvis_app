import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/domain/models/periodic_task.dart';

void main() {
  test('PeriodicTask.fromJson maps API contract', () {
    final task = PeriodicTask.fromJson({
      'id': 't1',
      'title': 'News',
      'instruction': 'Search AI news',
      'schedule': {
        'days_of_week': [0, 1, 2],
        'time': '08:00',
      },
      'timezone': 'Europe/Madrid',
      'notify_policy': 'on_change',
      'enabled': true,
      'thread_id': 'task:t1',
      'next_run_at': '2024-06-01T06:00:00+00:00',
      'next_reset_at': '2024-06-01T06:00:00+00:00',
      'next_reset_banner': 'Resets at next run',
      'latest_run': {
        'id': 'r1',
        'task_id': 't1',
        'started_at': '2024-05-31T06:00:00+00:00',
        'finished_at': '2024-05-31T06:00:05+00:00',
        'status': 'succeeded',
        'summary': 'Quiet day',
        'push_sent': false,
        'error': null,
      },
    });
    expect(task.id, 't1');
    expect(task.threadId, 'task:t1');
    expect(task.latestRun?.summary, 'Quiet day');
    expect(task.statusSubtitle, 'Quiet day');
    expect(task.nextResetBanner, 'Resets at next run');
  });

  test('PeriodicTask empty latest run shows Never run', () {
    final task = PeriodicTask.fromJson({
      'id': 't2',
      'title': 'X',
      'instruction': 'Y',
      'schedule': {
        'days_of_week': ['mon'],
        'time': '09:00',
      },
      'timezone': 'UTC',
      'notify_policy': 'always',
      'enabled': true,
      'thread_id': 'task:t2',
      'next_reset_banner': 'banner',
    });
    expect(task.latestRun, isNull);
    expect(task.statusSubtitle, 'Never run');
  });
}
