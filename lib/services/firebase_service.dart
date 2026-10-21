import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Firebase helpers used only in remote mode (dynamic API base URL).
class FirebaseService {
  static bool _initialized = false;

  static Future<void> ensureInit() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    _initialized = true;
  }

  /// Legacy alias — prefer [ensureInit] (lazy, remote-only).
  static Future<void> init() => ensureInit();

  Future<String?> fetchApiBaseUrl() async {
    await ensureInit();
    final dbRef = FirebaseDatabase.instance.ref('jarvis/latest_url');
    final snap = await dbRef.get();
    if (snap.exists) {
      return (snap.value as Map)['url'] as String;
    }
    return null;
  }
}
