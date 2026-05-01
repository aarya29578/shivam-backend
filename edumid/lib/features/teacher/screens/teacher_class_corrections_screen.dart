import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../corrections/corrections_repository.dart';
import 'package:go_router/go_router.dart';

class TeacherClassCorrectionsScreen extends StatefulWidget {
  final String className;
  const TeacherClassCorrectionsScreen({super.key, required this.className});

  @override
  State<TeacherClassCorrectionsScreen> createState() =>
      _TeacherClassCorrectionsScreenState();
}

class _TeacherClassCorrectionsScreenState
    extends State<TeacherClassCorrectionsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final repo = CorrectionsRepository.instance;
    final all = repo.listByClass(widget.className);
    final items =
        _filter == 'all' ? all : all.where((r) => r.status == _filter).toList();

    final pendingIds =
        all.where((r) => r.status == 'pending').map((r) => r.studentId).toSet();

    final filters = [
      ('All', 'all', all.length, null),
      (
        'Pending',
        'pending',
        all.where((r) => r.status == 'pending').length,
        AppColors.warning
      ),
      (
        'Approved',
        'approved',
        all.where((r) => r.status == 'approved').length,
        AppColors.success
      ),
      (
        'Rejected',
        'rejected',
        all.where((r) => r.status == 'rejected').length,
        AppColors.error
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Class ${widget.className}')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: filters.map((f) {
                final (label, value, count, color) = f;
                final selected = _filter == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$label ($count)'),
                    selected: selected,
                    selectedColor:
                        (color ?? AppColors.primary).withOpacity(0.18),
                    onSelected: (_) => setState(() => _filter = value),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.35)),
                    const SizedBox(height: 12),
                    Text('No requests',
                        style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55))),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final r = items[index];
                  final statusColor = r.status == 'pending'
                      ? AppColors.warning
                      : r.status == 'approved'
                          ? AppColors.success
                          : AppColors.error;
                  final statusIcon = r.status == 'pending'
                      ? Icons.hourglass_top_rounded
                      : r.status == 'approved'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded;

                  return Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.go('/teacher/corrections/${r.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              child: Text(
                                r.studentName
                                    .trim()
                                    .split(' ')
                                    .map((w) => w[0])
                                    .take(2)
                                    .join(),
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(r.studentName,
                                          style: AppTypography.labelLarge
                                              .copyWith(
                                                  fontWeight: FontWeight.w700)),
                                      if (pendingIds.contains(r.studentId) &&
                                          r.status == 'pending') ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.warning,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Roll ${r.rollNo}  •  ${r.requestedChanges.keys.join(', ')}',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.55)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  r.status[0].toUpperCase() +
                                      r.status.substring(1),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600),
                                ),
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
