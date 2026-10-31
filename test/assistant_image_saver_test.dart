import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_app/agent/images/assistant_image_saver.dart';

void main() {
  const url = 'http://192.168.1.10:8000/images/deadbeef';
  final pngBytes = Uint8List.fromList([1, 2, 3, 4]);

  test('fetches without Authorization and saves bytes', () async {
    Map<String, String>? seenHeaders;
    String? savedName;
    Uint8List? savedBytes;

    final saver = AssistantImageSaver(
      httpClient: MockClient((request) async {
        seenHeaders = request.headers;
        expect(request.url.toString(), url);
        return http.Response.bytes(
          pngBytes,
          200,
          headers: {
            'content-type': 'image/png',
            'content-disposition': 'inline; filename="deadbeef.png"',
          },
        );
      }),
      hasAccess: () async => true,
      requestAccess: () async => true,
      putImageBytes: (bytes, {required name}) async {
        savedBytes = bytes;
        savedName = name;
      },
    );

    expect(await saver.save(url), isNull);
    expect(seenHeaders?.containsKey('authorization'), isFalse);
    expect(seenHeaders?['Authorization'], isNull);
    expect(savedName, 'deadbeef');
    expect(savedBytes, pngBytes);
  });

  test('maps 404 to Image not found.', () async {
    final saver = AssistantImageSaver(
      httpClient: MockClient(
        (_) async => http.Response('{"detail":"Image not found."}', 404),
      ),
      hasAccess: () async => true,
      putImageBytes: (bytes, {required name}) async {},
    );
    expect(await saver.save(url), 'Image not found.');
  });

  test('reports permission denial in English', () async {
    final saver = AssistantImageSaver(
      httpClient: MockClient((_) async => http.Response('', 200)),
      hasAccess: () async => false,
      requestAccess: () async => false,
      putImageBytes: (bytes, {required name}) async {},
    );
    expect(await saver.save(url), 'Permission to save images is denied.');
  });

  test('reports a short error when the host blocks the fetch', () async {
    final saver = AssistantImageSaver(
      httpClient: MockClient((_) async => throw Exception('blocked')),
      hasAccess: () async => true,
      putImageBytes: (bytes, {required name}) async {},
    );
    expect(await saver.save(url), 'Could not download the image.');
  });
}
