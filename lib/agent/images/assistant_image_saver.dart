import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import 'assistant_image_url.dart';

/// Downloads an assistant image with no JWT and saves it to the photo gallery.
class AssistantImageSaver {
  AssistantImageSaver({
    http.Client? httpClient,
    Future<bool> Function()? hasAccess,
    Future<bool> Function()? requestAccess,
    Future<void> Function(Uint8List bytes, {required String name})? putImageBytes,
  })  : _http = httpClient ?? http.Client(),
        _hasAccess = hasAccess ?? Gal.hasAccess,
        _requestAccess = requestAccess ?? Gal.requestAccess,
        _putImageBytes = putImageBytes ??
            ((bytes, {required name}) => Gal.putImageBytes(bytes, name: name));

  final http.Client _http;
  final Future<bool> Function() _hasAccess;
  final Future<bool> Function() _requestAccess;
  final Future<void> Function(Uint8List bytes, {required String name})
      _putImageBytes;

  /// Returns `null` on success, or an English error message on failure.
  Future<String?> save(String url) async {
    try {
      var allowed = await _hasAccess();
      if (!allowed) {
        allowed = await _requestAccess();
      }
      if (!allowed) {
        return 'Permission to save images is denied.';
      }

      final response = await _http.get(
        Uri.parse(url),
        headers: const {'Accept': 'image/*,*/*'},
      );

      if (response.statusCode == 404) {
        return 'Image not found.';
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Could not download the image.';
      }
      if (response.bodyBytes.isEmpty) {
        return 'Could not download the image.';
      }

      final filename = filenameForAssistantImage(
        url: url,
        contentDisposition: response.headers['content-disposition'],
        contentType: response.headers['content-type'],
      );
      await _putImageBytes(
        response.bodyBytes,
        name: gallerySaveName(filename),
      );
      return null;
    } on GalException catch (e) {
      return e.type.message;
    } catch (_) {
      return 'Could not download the image.';
    }
  }
}
