import 'package:flutter/material.dart';

/// Fullscreen pinch-zoom viewer for an assistant chat image.
class ChatImageViewerPage extends StatefulWidget {
  const ChatImageViewerPage({
    required this.imageUrl,
    required this.onSave,
    this.imageProvider,
    super.key,
  });

  static const downloadKey = Key('chat_image_viewer_download');
  static const closeKey = Key('chat_image_viewer_close');

  final String imageUrl;
  final Future<String?> Function(String url) onSave;
  final ImageProvider? imageProvider;

  @override
  State<ChatImageViewerPage> createState() => _ChatImageViewerPageState();
}

class _ChatImageViewerPageState extends State<ChatImageViewerPage> {
  bool _saving = false;

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    final error = await widget.onSave(widget.imageUrl);
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Image saved to the gallery.')),
      );
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.imageProvider ?? NetworkImage(widget.imageUrl);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image(
                    image: provider,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load the image.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                key: ChatImageViewerPage.closeKey,
                tooltip: 'Close',
                color: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                key: ChatImageViewerPage.downloadKey,
                tooltip: 'Download',
                color: Colors.white,
                onPressed: _saving ? null : _download,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [ChatImageViewerPage] as a fullscreen route.
Future<void> openChatImageViewer(
  BuildContext context, {
  required String imageUrl,
  required Future<String?> Function(String url) onSave,
  ImageProvider? imageProvider,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatImageViewerPage(
        imageUrl: imageUrl,
        onSave: onSave,
        imageProvider: imageProvider,
      ),
      fullscreenDialog: true,
    ),
  );
}
