import 'dart:typed_data';

/// Fallback implementation for unsupported platforms.
Future<bool> saveImageImpl({
  required Uint8List bytes,
  required String fileName,
}) async {
  return false;
}
