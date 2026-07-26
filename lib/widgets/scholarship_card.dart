import 'package:flutter/material.dart';
import '../models/scholarship.dart';
import '../theme/app_colors.dart';

class ScholarshipCard extends StatelessWidget {
  final Scholarship scholarship;
  final VoidCallback? onApply;
  final VoidCallback? onTap;

  const ScholarshipCard({
    super.key,
    required this.scholarship,
    this.onApply,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final urgent = scholarship.daysLeft <= 5;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    scholarship.category.icon,
                    color: AppColors.primary,
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
                    color: urgent ? AppColors.dangerBg : AppColors.successBg,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    scholarship.daysLeft <= 0
                        ? 'Closing today'
                        : '${scholarship.daysLeft}d left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: urgent ? AppColors.danger : AppColors.success,
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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scholarship.provider,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                value: scholarship.fillRatio,
                minHeight: 6,
                backgroundColor: AppColors.neutralBg,
                valueColor: AlwaysStoppedAnimation(
                  scholarship.slotsLeft == 0
                      ? AppColors.danger
                      : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scholarship.slotsLeft > 0
                  ? '${scholarship.slotsLeft} slots left of ${scholarship.totalSlots}'
                  : 'Slots full',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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
                    color: AppColors.primary,
                  ),
                ),
                FilledButton(
                  onPressed: scholarship.slotsLeft == 0 ? null : onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
