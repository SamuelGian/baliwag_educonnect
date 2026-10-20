import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Downscales/recompresses a JPEG or PNG so it fits under [maxBytes] —
/// tries reducing JPEG quality first, then shrinking dimensions, repeating
/// until it fits (or a floor is reached). This is what keeps a typical
/// 3-8MB phone camera photo from tripping the Firestore per-document size
/// cap (see [kMaxDocumentFileBytes] in document_upload_limits.dart)
/// instead of just rejecting the upload outright.
///
/// PDFs and files that are already small enough pass through unchanged —
/// re-encoding always happens as JPEG, so [fileName]'s extension is
/// adjusted to match when that happens.
({Uint8List bytes, String fileName}) compressImageToFit(
  Uint8List bytes,
  String fileName,
  int maxBytes,
) {
  if (bytes.length <= maxBytes) return (bytes: bytes, fileName: fileName);

  final ext = fileName.split('.').last.toLowerCase();
  if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
    return (bytes: bytes, fileName: fileName);
  }

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return (bytes: bytes, fileName: fileName);
  }
  if (decoded == null) return (bytes: bytes, fileName: fileName);

  var current = decoded;
  var quality = 85;
  var best = bytes;

  for (var attempt = 0; attempt < 8; attempt++) {
    final encoded = Uint8List.fromList(
      img.encodeJpg(current, quality: quality),
    );
    best = encoded;
    if (encoded.length <= maxBytes) break;
    if (quality > 40) {
      quality -= 15;
    } else {
      current = img.copyResize(current, width: (current.width * 0.8).round());
    }
  }

  final dot = fileName.lastIndexOf('.');
  final newName = dot == -1
      ? '$fileName.jpg'
      : '${fileName.substring(0, dot)}.jpg';
  return (bytes: best, fileName: newName);
}
