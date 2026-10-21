import 'firebase_service.dart';

/// Shared resolver for the published Jarvis FastAPI base URL.
class RemoteEndpoint {
  RemoteEndpoint({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService();

  final FirebaseService _firebase;
  String? _baseUrl;

  /// True when the response likely means the published tunnel URL is stale.
  static bool isStaleTunnelStatus(int statusCode) =>
      statusCode == 404 || statusCode == 1016;

  Future<String?> resolve({bool forceRefresh = false}) async {
    if (!forceRefresh && _baseUrl != null) return _baseUrl;
    await FirebaseService.ensureInit();
    _baseUrl = await _firebase.fetchApiBaseUrl();
    return _baseUrl;
  }

  Future<String> requireBaseUrl({bool forceRefresh = false}) async {
    final url = await resolve(forceRefresh: forceRefresh);
    if (url == null || url.isEmpty) {
      throw StateError(
        'Jarvis API base URL is missing. Check Firebase jarvis/latest_url.',
      );
    }
    return url;
  }
}
