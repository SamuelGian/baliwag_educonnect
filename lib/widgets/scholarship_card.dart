import 'package:flutter/material.dart';
import '../models/scholarship.dart';
import '../theme/app_theme_context.dart';

class ScholarshipCard extends StatelessWidget {
  final Scholarship scholarship;
  final VoidCallback? onApply;

  /// Overrides the button's label when [onApply] is null because the
  /// caller has already determined the student can't apply right now
  /// (already applied, deadline passed, etc. — see AppState.blockReasonFor)
  /// rather than just because slots are full.
  final String? applyLabel;
  final VoidCallback? onTap;

  const ScholarshipCard({
    super.key,
    required this.scholarship,
    this.onApply,
    this.applyLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Driven by the same getScholarshipStatus() the admin's Manage
    // Scholarships list uses — previously this chip only ever reflected
    // deadline urgency, so a manually-closed or slots-full program with a
    // distant deadline still showed a calm green "Xd left" here.
    final status = getScholarshipStatus(scholarship);
    final urgent = status != ScholarshipStatus.active;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appColors.border),
          boxShadow: [
            BoxShadow(
              color: context.appColors.cardShadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    scholarship.category.icon,
                    color: context.scheme.primary,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: urgent
                        ? context.appColors.dangerBg
                        : context.appColors.successBg,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    // The day-count is only meaningful while the deadline
                    // is actually the relevant fact — once slots are full
                    // or an admin has closed it early, the status label
                    // itself ("Slots Full", "Closed") is more accurate
                    // than a stale "12d left".
                    switch (status) {
                      ScholarshipStatus.active =>
                        '${scholarship.daysLeft}d left',
                      ScholarshipStatus.closingSoon =>
                        scholarship.daysLeft <= 0
                            ? 'Closing today'
                            : '${scholarship.daysLeft}d left',
                      _ => status.label,
                    },
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: urgent
                          ? context.scheme.error
                          : context.appColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              scholarship.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: context.appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scholarship.provider,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                value: scholarship.fillRatio,
                minHeight: 6,
                backgroundColor: context.appColors.neutralBg,
                valueColor: AlwaysStoppedAnimation(
                  scholarship.slotsLeft == 0
                      ? context.scheme.error
                      : context.scheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scholarship.slotsLeft > 0
                  ? '${scholarship.slotsLeft} slots left of ${scholarship.totalSlots}'
                  : 'Slots full',
              style: TextStyle(
                fontSize: 11.5,
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱${scholarship.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.scheme.primary,
                  ),
                ),
                FilledButton(
                  onPressed: (onApply == null || scholarship.slotsLeft == 0)
                      ? null
                      : onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.scheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    onApply == null
                        ? (applyLabel ?? 'Unavailable')
                        : (scholarship.slotsLeft == 0 ? 'Slots Full' : 'Apply'),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
