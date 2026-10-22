import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// How a remote call failed — drives offline failover vs auth UX.
enum RemoteFailureKind {
  /// Connectivity, timeout, missing base URL, DNS, etc.
  transport,

  /// 401 / 403 — do not enter offline; user must fix credentials.
  auth,

  /// Reachable server returned a non-auth application error.
  other,
}

class JarvisRemoteException implements Exception {
  JarvisRemoteException(
    this.message, {
    this.statusCode,
    this.kind = RemoteFailureKind.other,
  });

  final String message;
  final int? statusCode;
  final RemoteFailureKind kind;

  @override
  String toString() => message;
}

/// True when Auto mode may fall back to on-device OpenAI.
bool isFailoverCandidate(Object error) {
  return classifyRemoteFailure(error) == RemoteFailureKind.transport;
}

RemoteFailureKind classifyRemoteFailure(Object error) {
  if (error is JarvisRemoteException) {
    return error.kind;
  }
  if (error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is HandshakeException ||
      error is http.ClientException) {
    return RemoteFailureKind.transport;
  }
  if (error is StateError) {
    final msg = error.message;
    if (msg.contains('base URL') || msg.contains('missing')) {
      return RemoteFailureKind.transport;
    }
  }
  return RemoteFailureKind.other;
}

RemoteFailureKind kindFromStatusCode(int statusCode) {
  if (statusCode == 401 || statusCode == 403) {
    return RemoteFailureKind.auth;
  }
  return RemoteFailureKind.other;
}

/// Offline wanted but no OpenAI key on device.
class OfflineKeyRequiredException implements Exception {
  OfflineKeyRequiredException([
    this.message =
        'Jarvis Server is unreachable and no OpenAI API key is configured. '
            'Open Settings to add a key for offline mode, or wait until the server is back.',
  ]);

  final String message;

  @override
  String toString() => message;
}
