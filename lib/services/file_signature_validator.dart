import 'dart:typed_data';

/// Verifies a file's actual content matches one of the document types this
/// app accepts (PDF, JPEG, PNG) by checking its magic-byte signature —
/// not just its filename extension. A file picker's `allowedExtensions`
/// filter is a UI convenience, not a security boundary: it never inspects
/// what's actually inside the file, so a renamed file of any type sails
/// straight through it.
bool looksLikeAcceptedDocument(Uint8List bytes) {
  if (bytes.length < 4) return false;

  // PDF: starts with "%PDF"
  if (bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46) {
    return true;
  }

  // JPEG: starts with FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }

  // PNG: starts with 89 50 4E 47
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }

  return false;
}
