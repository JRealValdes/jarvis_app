import 'dart:io';

import '../agent/backend_factory.dart';
import '../data/secure_store.dart';
import 'notification_router.dart';
import 'push_payload.dart';

/// Registers device tokens with Jarvis and routes notification taps.
///
/// Real FCM delivery needs Firebase project config on the device. Until then,
/// [registerToken] still posts to `/devices/register` so the backend contract
/// can be dogfooded with a test token from Settings.
class PushService {
  PushService({
    BackendFactory? factory,
    SecureStore? secureStore,
    NotificationRouter? router,
  })  : _factory = factory ?? BackendFactory(),
        _store = secureStore ?? SecureStore(),
        _router = router ?? NotificationRouter();

  final BackendFactory _factory;
  final SecureStore _store;
  final NotificationRouter _router;

  /// Platform label expected by the FastAPI devices API.
  String get platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  Future<String?> savedToken() => _store.getPushDeviceToken();

  /// Register [token] with the backend and remember it locally.
  Future<void> registerToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) return;
    final api = await _factory.createRemote();
    await api.registerDeviceToken(token: clean, platform: platform);
    await _store.setPushDeviceToken(clean);
  }

  /// Unregister the saved token (best-effort).
  Future<void> unregisterSavedToken() async {
    final token = await savedToken();
    if (token == null || token.isEmpty) return;
    try {
      final api = await _factory.createRemote();
      await api.unregisterDeviceToken(token);
    } catch (_) {}
    await _store.clearPushDeviceToken();
  }

  /// Handle a raw data map from FCM / local notification tap.
  Future<void> handleData(Map<String, dynamic> data) async {
    final payload = PushPayload.tryParse(data);
    if (payload == null) return;
    await _router.open(payload);
  }
}
