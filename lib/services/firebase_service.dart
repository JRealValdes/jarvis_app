import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static Future<void> init() async {
    await Firebase.initializeApp();
  }

  Future<String?> fetchApiBaseUrl() async {
    final dbRef = FirebaseDatabase.instance.ref('jarvis/latest_url');
    final snap = await dbRef.get();
    if (snap.exists) {
      return (snap.value as Map)['url'] as String;
    }
    return null;
  }
}
