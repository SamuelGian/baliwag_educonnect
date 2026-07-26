import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/application.dart';
import '../theme/app_colors.dart';
import '../widgets/doc_match_badge.dart';
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
    final wide = MediaQuery.of(context).size.width >= 900;
    final apps = app.myApplications;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Tracker',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Monitor the progress, document verification, and admin messages for your applications.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
    );
  }
}

class _EmptyTracker extends StatelessWidget {
  const _EmptyTracker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('No applications yet', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Apply to a scholarship from the Apply tab to start tracking it here.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ScholarshipApplication app;

  const _ApplicationCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
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
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${app.id} • Submitted ${DateFormat('MMM d, y').format(app.dateSubmitted)}',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
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
          const Text('Documents', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          for (final d in app.documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.name,
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(child: DocMatchBadge(status: d.matchStatus, note: d.matchNote)),
                ],
              ),
            ),
          if (app.messages.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Messages from Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            for (final m in app.messages)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(m.sender, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(m.date),
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                color: i <= current ? (rejected && i == current ? AppColors.danger : AppColors.primary) : AppColors.border,
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
                        ? AppColors.primary
                        : i == current
                            ? (rejected ? AppColors.danger : AppColors.primary)
                            : AppColors.neutralBg,
                    border: Border.all(
                      color: i <= current ? (rejected && i == current ? AppColors.danger : AppColors.primary) : AppColors.border,
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
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    color: i <= current ? AppColors.textPrimary : AppColors.textMuted,
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
