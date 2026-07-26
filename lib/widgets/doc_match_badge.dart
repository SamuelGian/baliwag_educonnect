import 'package:flutter/material.dart';
import '../models/application.dart';
import '../theme/app_colors.dart';

/// Visualizes the OCR document-vs-record match status produced by
/// AppState._verifyDocuments (see lib/services/ocr_service.dart).
class DocMatchBadge extends StatelessWidget {
  final DocMatchStatus status;
  final String? note;

  const DocMatchBadge({super.key, required this.status, this.note});

  @override
  Widget build(BuildContext context) {
    final badge = _build(context);
    if (note == null || note!.isEmpty) return badge;
    return Tooltip(message: note!, child: badge);
  }

  Widget _build(BuildContext context) {
    switch (status) {
      case DocMatchStatus.pending:
        return _badge(
          icon: Icons.upload_file_rounded,
          label: 'Not uploaded',
          color: AppColors.textMuted,
          bg: AppColors.neutralBg,
        );
      case DocMatchStatus.verifying:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Verifying with OCR…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ),
          ],
        );
      case DocMatchStatus.matched:
        return _badge(
          icon: Icons.verified_rounded,
          label: 'Matched with student record',
          color: AppColors.success,
          bg: AppColors.successBg,
        );
      case DocMatchStatus.mismatch:
        return _badge(
          icon: Icons.error_rounded,
          label: 'Needs manual review',
          color: AppColors.danger,
          bg: AppColors.dangerBg,
        );
    }
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
