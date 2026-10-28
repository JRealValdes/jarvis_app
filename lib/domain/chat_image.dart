/// One image on `POST /ask` (`media_type` + raw base64, or a data URL).
class ChatImage {
  const ChatImage({
    required this.mediaType,
    required this.dataBase64,
  });

  /// `image/jpeg`, `image/png`, `image/gif`, or `image/webp`.
  final String mediaType;

  /// Raw base64, without a `data:` prefix.
  final String dataBase64;

  Map<String, String> toAskJson() => {
        'media_type': mediaType,
        'data_base64': dataBase64,
      };
}
