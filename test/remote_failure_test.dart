import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/agent/remote/remote_failure.dart';

void main() {
  group('classifyRemoteFailure', () {
    test('transport: timeout and socket', () {
      expect(
        classifyRemoteFailure(TimeoutException('x')),
        RemoteFailureKind.transport,
      );
      expect(
        classifyRemoteFailure(const SocketException('unreachable')),
        RemoteFailureKind.transport,
      );
    });

    test('transport: missing base URL StateError', () {
      expect(
        classifyRemoteFailure(
          StateError(
            'Jarvis API base URL is missing. Set it in Settings '
            '(LAN IP or Tailscale MagicDNS / 100.x).',
          ),
        ),
        RemoteFailureKind.transport,
      );
    });

    test('auth: 401/403 via JarvisRemoteException', () {
      expect(
        classifyRemoteFailure(
          JarvisRemoteException('nope', statusCode: 401, kind: RemoteFailureKind.auth),
        ),
        RemoteFailureKind.auth,
      );
      expect(isFailoverCandidate(
        JarvisRemoteException('nope', statusCode: 401, kind: RemoteFailureKind.auth),
      ), isFalse);
    });

    test('failover candidates are transport only', () {
      expect(
        isFailoverCandidate(TimeoutException('t')),
        isTrue,
      );
      expect(
        isFailoverCandidate(
          JarvisRemoteException('500', statusCode: 500, kind: RemoteFailureKind.other),
        ),
        isFalse,
      );
    });

    test('kindFromStatusCode', () {
      expect(kindFromStatusCode(401), RemoteFailureKind.auth);
      expect(kindFromStatusCode(403), RemoteFailureKind.auth);
      expect(kindFromStatusCode(404), RemoteFailureKind.other);
      expect(kindFromStatusCode(500), RemoteFailureKind.other);
    });
  });
}
