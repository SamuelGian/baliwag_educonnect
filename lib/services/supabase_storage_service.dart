import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class SupabaseStorageException implements Exception {
  final String message;
  SupabaseStorageException(this.message);
  @override
  String toString() => message;
}

/// Maps a file's extension to its MIME type — used both as the Content-Type
/// header on upload and to decide how the admin viewer should render a
/// signed URL (inline image vs. "open PDF" button).
String mimeTypeForFileName(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

/// One object per (application, requirement) pair — resubmitting a document
/// re-uploads to this same path (see [SupabaseStorageService.upload]'s
/// upsert), so a replacement overwrites the old file instead of
/// accumulating orphaned objects in the bucket.
String objectPathFor(
  String applicationId,
  String documentName,
  String fileName,
) {
  final slug = documentName.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  final ext = fileName.split('.').last.toLowerCase();
  return '$applicationId/$slug.$ext';
}

/// Thin client for the Supabase Storage REST API against the private
/// `documents` bucket — plain HTTP calls (same style as [OcrService]) rather
/// than the full supabase_flutter SDK, since upload + signed-URL generation
/// is all this app needs.
///
/// The bucket is private, so a URL is never persisted to Firestore — only
/// the object path (see [objectPathFor]) is saved, on
/// [DocumentItem.storagePath]. Viewing a file means minting a fresh,
/// time-limited signed URL on demand (see [createSignedUrl]); a saved URL
/// would eventually expire and leave the admin viewer permanently broken.
class SupabaseStorageService {
  static const _bucket = 'documents';

  /// Uploads [bytes] to `documents/[path]`, overwriting any existing object
  /// there (`x-upsert`). Returns [path] unchanged — the caller persists it.
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = Uri.parse('$supabaseUrl/storage/v1/object/$_bucket/$path');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'apikey': supabaseAnonKey,
              'Authorization': 'Bearer $supabaseAnonKey',
              'Content-Type': mimeType,
              'x-upsert': 'true',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw SupabaseStorageException('Could not reach storage service: $e');
    }
    if (response.statusCode != 200) {
      throw SupabaseStorageException(
        'Storage upload failed (${response.statusCode}).',
      );
    }
    return path;
  }

  /// Mints a short-lived signed URL for viewing a private object. Called
  /// fresh every time the admin viewer opens a document rather than once at
  /// upload time, so a URL is never stored stale/expired.
  Future<String> createSignedUrl(
    String path, {
    int expiresInSeconds = 3600,
  }) async {
    final uri = Uri.parse('$supabaseUrl/storage/v1/object/sign/$_bucket/$path');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'apikey': supabaseAnonKey,
              'Authorization': 'Bearer $supabaseAnonKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'expiresIn': expiresInSeconds}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw SupabaseStorageException('Could not reach storage service: $e');
    }
    if (response.statusCode != 200) {
      throw SupabaseStorageException(
        'Could not generate a view link (${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final signedPath = body['signedURL'] as String?;
    if (signedPath == null || signedPath.isEmpty) {
      throw SupabaseStorageException('Storage service returned no view link.');
    }
    return '$supabaseUrl/storage/v1$signedPath';
  }
}
