import 'dart:typed_data';
import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart'
    if (dart.library.io) 'file_downloader_io.dart';

/// Cross-platform helper to download or save images.
abstract class FileDownloader {
  /// Saves the given [bytes] as a file with [fileName].
  /// Returns `true` if initiated/saved successfully.
  static Future<bool> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) {
    return saveImageImpl(bytes: bytes, fileName: fileName);
  }
}
