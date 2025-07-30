import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final _storage = FlutterSecureStorage();

  static const _keyThreadId = 'thread_id';

  static Future<void> saveThreadId(String threadId) async {
    await _storage.write(key: _keyThreadId, value: threadId);
  }

  static Future<String?> getThreadId() async {
    return await _storage.read(key: _keyThreadId);
  }

  static Future<void> deleteThreadId() async {
    await _storage.delete(key: _keyThreadId);
  }
}
