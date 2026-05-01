import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../corrections/corrections_repository.dart';
import 'package:go_router/go_router.dart';

class TeacherCorrectionsOverviewScreen extends StatefulWidget {
  const TeacherCorrectionsOverviewScreen({super.key});

  @override
  State<TeacherCorrectionsOverviewScreen> createState() =>
      _TeacherCorrectionsOverviewScreenState();
}

class _TeacherCorrectionsOverviewScreenState
    extends State<TeacherCorrectionsOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = CorrectionsRepository.instance;
    final all = repo.listAll();

    // Build per-class stats
    final Map<String, Map<String, int>> stats = {};
    for (final r in all) {
      stats.putIfAbsent(r.className,
          () => {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0});
      stats[r.className]!['total'] = stats[r.className]!['total']! + 1;
      if (r.status == 'pending')
        stats[r.className]!['pending'] = stats[r.className]!['pending']! + 1;
      if (r.status == 'approved')
        stats[r.className]!['approved'] = stats[r.className]!['approved']! + 1;
      if (r.status == 'rejected')
        stats[r.className]!['rejected'] = stats[r.className]!['rejected']! + 1;
    }
    for (final c in ['IX-A', 'X-A', 'X-B']) {
      stats.putIfAbsent(
          c, () => {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0});
    }

    final classes = stats.keys.toList()..sort();
    final totalPending = all.where((r) => r.status == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correction Requests'),
        actions: [
          if (totalPending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Chip(
                label: Text('$totalPending pending',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.error,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Select a class to view students who have submitted correction requests.',
              style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.55)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final cls = classes[i];
                final s = stats[cls]!;
                final pending = s['pending']!;
                final approved = s['approved']!;
                final rejected = s['rejected']!;
                final total = s['total']!;

                return Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go('/teacher/corrections/class/$cls'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.class_rounded,
                                color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Class $cls',
                                    style: AppTypography.titleMedium
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (pending > 0)
                                      _StatusPill('$pending Pending',
                                          AppColors.warning),
                                    if (approved > 0)
                                      _StatusPill('$approved Approved',
                                          AppColors.success),
                                    if (rejected > 0)
                                      _StatusPill('$rejected Rejected',
                                          AppColors.error),
                                    if (total == 0)
                                      _StatusPill(
                                          'No requests',
                                          Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.45)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (total > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$total total',
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(height: 6),
                              Icon(Icons.chevron_right_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.45)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
