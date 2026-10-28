import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ephemeral `.m4a` path under the app temp directory.
Future<String> newMicClipPath() async {
  final dir = await getTemporaryDirectory();
  final name = 'jarvis-mic-${DateTime.now().microsecondsSinceEpoch}.m4a';
  return p.join(dir.path, name);
}
