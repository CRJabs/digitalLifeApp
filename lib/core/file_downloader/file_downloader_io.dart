import 'dart:io';
import 'dart:typed_data';

/// Native (Desktop/Mobile) implementation for file saving.
Future<bool> saveImageImpl({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    String? targetDirPath;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (downloads.existsSync()) {
          targetDirPath = downloads.path;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final downloads = Directory('$home/Downloads');
        if (downloads.existsSync()) {
          targetDirPath = downloads.path;
        }
      }
    }

    targetDirPath ??= Directory.current.path;
    final file = File('$targetDirPath${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return true;
  } catch (_) {
    return false;
  }
}
