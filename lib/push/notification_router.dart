import 'package:flutter/material.dart';

import '../agent/backend_factory.dart';
import '../navigation/app_navigator.dart';
import '../screens/chat_screen.dart';
import '../screens/task_chat_screen.dart';
import 'push_payload.dart';

/// Opens the right screen when a push notification is tapped.
class NotificationRouter {
  NotificationRouter({BackendFactory? factory})
      : _factory = factory ?? BackendFactory();

  final BackendFactory _factory;

  /// Route from a parsed payload. Safe to call cold-start or mid-session.
  Future<void> open(PushPayload payload) async {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    if (payload.isPeriodicTask) {
      try {
        final api = await _factory.createRemote();
        final task = await api.getTask(payload.taskId!);
        await nav.push(
          MaterialPageRoute(
            builder: (_) => TaskChatScreen(task: task),
          ),
        );
      } catch (_) {
        // Fall through to main chat if the task cannot be loaded.
        await nav.push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
      return;
    }

    if (payload.isChatJob) {
      await nav.push(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }
}
