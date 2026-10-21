import 'openai_client.dart';

/// User-facing copy for local/offline OpenAI failures.
String describeOpenAiError(Object error) {
  if (error is OpenAiException) {
    switch (error.statusCode) {
      case 401:
        return 'Invalid OpenAI API key. Open Settings and paste a valid key.';
      case 429:
        return 'OpenAI rate limit exceeded. Please try again in a moment.';
      case 403:
        return 'OpenAI refused the request (403). Check your API key and billing.';
      default:
        if (error.statusCode != null) {
          return 'OpenAI error (${error.statusCode}). ${error.message}';
        }
        return error.message;
    }
  }

  final text = error.toString();
  if (text.contains('API key is missing') ||
      text.contains('OpenAI API key')) {
    return 'OpenAI API key is missing. Open Settings and paste your key.';
  }
  return 'There was an error processing your request. $text';
}
