import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/document_upload_limits.dart';
import '../models/application.dart';
import '../services/document_gate_service.dart';
import '../services/file_signature_validator.dart';
import '../services/image_compression_service.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../widgets/ambient_background.dart';
import '../widgets/doc_match_badge.dart';
import '../widgets/glass_panel.dart';
import '../widgets/local_file_preview_dialog.dart';
import '../widgets/status_chip.dart';

const _stages = [
  'Submitted',
  'Document Verification',
  'Under Review',
  'Decision',
];

class ApplicationTrackerScreen extends StatelessWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;
    final apps = app.myApplications;

    return AmbientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          // Extra bottom clearance on narrow screens only, so the last
          // application card can scroll clear of the floating GlassNavBar
          // instead of ending up hidden under it.
          padding: EdgeInsets.fromLTRB(
            wide ? 32 : 18,
            24,
            wide ? 32 : 18,
            wide ? 24 : 120,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Tracker',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor the progress, document verification, and admin messages for your applications.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                if (apps.isEmpty)
                  const _EmptyTracker()
                else
                  for (final a in apps) ...[
                    _ApplicationCard(app: a),
                    const SizedBox(height: 18),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTracker extends StatelessWidget {
  const _EmptyTracker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassPanel(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 40,
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No applications yet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Apply to a scholarship from the Apply tab to start tracking it here.',
              style: TextStyle(
                fontSize: 12.5,
                color: context.appColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ScholarshipApplication app;

  const _ApplicationCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.scholarshipTitle,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${app.id} • Submitted ${DateFormat('MMM d, y').format(app.dateSubmitted)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: app.status),
            ],
          ),
          const SizedBox(height: 20),
          _Timeline(status: app.status),
          const SizedBox(height: 20),
          const Text(
            'Documents',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final d in app.documents)
            _DocumentRow(applicationId: app.id, doc: d),
          if (app.messages.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Messages from Admin',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (final m in app.messages)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appColors.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(m.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(m.message, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DocumentRow extends StatefulWidget {
  final String applicationId;
  final DocumentItem doc;

  const _DocumentRow({required this.applicationId, required this.doc});

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _uploading = false;
  final _gateService = DocumentGateService();

  /// Most recent [DocumentGateService] rejection reason for this
  /// document's re-upload attempt, if any — shown as a persistent note
  /// below the row (not just the transient SnackBar shown at the moment of
  /// rejection, which is easy to miss). Cleared on a successful re-upload.
  String? _gateRejectionNote;

  Future<void> _reupload() async {
    PlatformFile file;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      file = result.files.single;
      if (file.bytes == null) return;
    } catch (_) {
      return;
    }

    if (!mounted) return;
    var bytes = file.bytes!;
    var fileName = file.name;
    if (!looksLikeAcceptedDocument(bytes)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This file doesn't look like a valid PDF, JPG, or PNG. "
            'Please choose a different file.',
          ),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final gateResult = await _gateService
          .check(
            bytes: bytes,
            fileName: fileName,
            expectedDocumentName: widget.doc.name,
          )
          .timeout(const Duration(seconds: 30));
      if (!gateResult.accepted) {
        final message =
            'This looks like ${gateResult.detectedContent}, not '
            '"${widget.doc.name}". Please upload the correct document.';
        if (mounted) {
          setState(() => _gateRejectionNote = message);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
      if (mounted) setState(() => _gateRejectionNote = null);
    } catch (e) {
      // Infrastructure failure, not a content verdict — let it through to
      // the existing OCR pipeline rather than blocking the resubmission.
      // Still surfaced (not silent) so a persistent failure here is
      // visible and diagnosable instead of looking like the gate quietly
      // approved it.
      debugPrint('Document gate check failed, letting file through: $e');
      if (mounted) {
        setState(() => _gateRejectionNote = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not auto-verify this document right now — it will '
              'still be checked after you submit.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    if (!mounted) return;

    if (bytes.length > kMaxDocumentFileBytes) {
      final compressed = compressImageToFit(
        bytes,
        fileName,
        kMaxDocumentFileBytes,
      );
      bytes = compressed.bytes;
      fileName = compressed.fileName;
    }
    if (bytes.length > kMaxDocumentFileBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This file is too large even after compression (max ${(kMaxDocumentFileBytes / (1024 * 1024)).round()}MB). '
            'Please upload a smaller PDF or a lower-resolution photo.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => LocalFilePreviewDialog(
        bytes: bytes,
        fileName: fileName,
        showConfirmActions: true,
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _uploading = true);
    final appState = context.read<AppState>();
    try {
      await appState.resubmitDocument(
        applicationId: widget.applicationId,
        documentName: widget.doc.name,
        fileName: fileName,
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final needsResubmission = d.matchStatus == DocMatchStatus.needsResubmission;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.name,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: DocMatchBadge(
                  status: d.matchStatus,
                  note: d.adminFeedback ?? d.matchNote,
                ),
              ),
            ],
          ),
          if (needsResubmission)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.adminFeedback != null &&
                        d.adminFeedback!.trim().isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 15,
                            color: context.scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.adminFeedback!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_gateRejectionNote != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 15,
                            color: context.scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _gateRejectionNote!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _reupload,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.scheme.error,
                          side: BorderSide(color: context.scheme.error),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: _uploading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.scheme.error,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded, size: 15),
                        label: Text(
                          _uploading ? 'Uploading…' : 'Re-upload Document',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final ApplicationStatus status;

  const _Timeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final current = status.stepIndex;
    final rejected = status == ApplicationStatus.rejected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stages.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: 13),
                color: i <= current
                    ? (rejected && i == current
                          ? context.scheme.error
                          : context.scheme.primary)
                    : context.appColors.border,
              ),
            ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < current
                        ? context.scheme.primary
                        : i == current
                        ? (rejected
                              ? context.scheme.error
                              : context.scheme.primary)
                        : context.appColors.neutralBg,
                    border: Border.all(
                      color: i <= current
                          ? (rejected && i == current
                                ? context.scheme.error
                                : context.scheme.primary)
                          : context.appColors.border,
                    ),
                  ),
                  child: i < current
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : i == current
                      ? Icon(
                          rejected ? Icons.close_rounded : Icons.circle,
                          size: rejected ? 14 : 8,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _stages[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= current
                        ? context.appColors.textPrimary
                        : context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
