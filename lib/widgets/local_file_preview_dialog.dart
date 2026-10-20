import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_storage_service.dart';

/// Shows a locally-picked file — before it's ever sent anywhere — so a
/// student can confirm they selected the right document. Used at both
/// first-submission time (Documents step, where nothing uploads until the
/// final Submit anyway) and at resubmission time, where [showConfirmActions]
/// gates the file on an explicit "Use This File" before
/// AppState.resubmitDocument actually sends it — cancelling here leaves the
/// document's previous state untouched.
class LocalFilePreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final bool showConfirmActions;

  const LocalFilePreviewDialog({
    super.key,
    required this.bytes,
    required this.fileName,
    this.showConfirmActions = false,
  });

  bool get _isImage => mimeTypeForFileName(fileName).startsWith('image/');

  Future<void> _openPdfInNewTab() async {
    final uri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!showConfirmActions)
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
            if (showConfirmActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        child: const Text('Choose a Different File'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Use This File'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_isImage) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 14),
              Text(
                fileName,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openPdfInNewTab,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open PDF in New Tab'),
              ),
            ],
          ),
        ),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
    );
  }
}
