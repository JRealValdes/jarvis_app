import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../config/app_config.dart';
import '../openai/openai_client.dart';
import 'audio_transcriber.dart';

/// On-device Whisper call using the Settings API key.
///
/// This client never talks to Jarvis `/transcribe`.
class OpenAiWhisperClient implements AudioTranscriber {
  OpenAiWhisperClient({
    required this.apiKey,
    http.Client? httpClient,
    this.transcriptionsUrl = AppConfig.openAiAudioTranscriptionsUrl,
    Duration? timeout,
  })  : _http = httpClient ?? http.Client(),
        _timeout = timeout ?? AppConfig.remoteTranscribeTimeout;

  final String apiKey;
  final String transcriptionsUrl;
  final http.Client _http;
  final Duration _timeout;

  @override
  Future<String> transcribe({
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(transcriptionsUrl));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Accept'] = 'application/json';
    request.fields['model'] = AppConfig.whisperModel;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('application', 'octet-stream'),
      ),
    );
    final response = await () async {
      final streamed = await _http.send(request);
      return http.Response.fromStream(streamed);
    }()
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiException(
        'OpenAI transcription failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['text'] is! String) {
      throw OpenAiException('OpenAI returned no transcription');
    }
    return decoded['text'] as String;
  }
}
