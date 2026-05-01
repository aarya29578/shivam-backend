import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../reprint/reprint_repository.dart';
import '../../reprint/models/reprint_request.dart';

class TeacherReprintRequestsScreen extends StatefulWidget {
  const TeacherReprintRequestsScreen({super.key});

  @override
  State<TeacherReprintRequestsScreen> createState() =>
      _TeacherReprintRequestsScreenState();
}

class _TeacherReprintRequestsScreenState
    extends State<TeacherReprintRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ReprintRepository.instance;
  late final TabController _tab;

  static const _statuses = ['pending', 'approved', 'rejected'];
  static const _tabLabels = ['Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    _repo.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _tab.dispose();
    _repo.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() => setState(() {});

  List<ReprintRequest> get _filtered {
    final status = _statuses[_tab.index];
    return _repo.requests.where((r) => r.status == status).toList();
  }

  void _updateStatus(ReprintRequest request, String status) {
    _repo.updateStatus(request.id, status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'approved'
              ? 'Reprint request approved for ${request.studentName}'
              : 'Reprint request rejected for ${request.studentName}',
        ),
        backgroundColor:
            status == 'approved' ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reprint Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: requests.isEmpty
          ? EmptyState(
              title: 'No ${_tabLabels[_tab.index]} Requests',
              subtitle: 'No reprint requests in this category yet.',
              icon: Icons.print_disabled_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final req = requests[i];
                return _ReprintRequestCard(
                  request: req,
                  onApprove: req.status == 'pending'
                      ? () => _updateStatus(req, 'approved')
                      : null,
                  onReject: req.status == 'pending'
                      ? () => _updateStatus(req, 'rejected')
                      : null,
                ).animate().fadeIn(
                      delay: Duration(milliseconds: 80 * i),
                      duration: 350.ms,
                    );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reprint request card
// ─────────────────────────────────────────────────────────────────────────────
class _ReprintRequestCard extends StatelessWidget {
  final ReprintRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ReprintRequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  Color get _statusColor => switch (request.status) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  String get _statusLabel => switch (request.status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending',
      };

  IconData get _statusIcon => switch (request.status) {
        'approved' => Icons.check_circle_rounded,
        'rejected' => Icons.cancel_rounded,
        _ => Icons.hourglass_top_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.studentName, style: AppTypography.labelLarge),
                    Text(
                      'Class ${request.className}  •  Roll ${request.rollNo}',
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel,
                      style: AppTypography.caption.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Request meta
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                ),
                const SizedBox(width: 6),
                Text(
                  'Requested on ${_formatDate(request.createdAt)}',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                ),
                const Spacer(),
                Text(
                  'Type: ${request.requestType}',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),

          // Action buttons — only for pending
          if (request.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      'Reject',
                      style: AppTypography.labelMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Approve',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
