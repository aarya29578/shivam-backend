import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION CENTER
// ═══════════════════════════════════════════════════════════════════
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Mark all read'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _NotifList(filter: null),
          _NotifList(filter: 'unread'),
          const ActivityFeedScreen(),
        ],
      ),
    );
  }
}

class _NotifList extends StatelessWidget {
  final String? filter;
  const _NotifList({this.filter});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NItem(
          Icons.approval_rounded,
          'Proof Approved',
          'Principal has approved your design proof for School A',
          AppColors.success,
          false,
          '2m ago'),
      _NItem(
          Icons.error_rounded,
          'Data Error',
          '12 records have validation errors in School B upload',
          AppColors.error,
          true,
          '15m ago'),
      _NItem(
          Icons.local_shipping_rounded,
          'Order Dispatched',
          'ORD-2025-042 has been dispatched via BlueDart',
          AppColors.primary,
          true,
          '1h ago'),
      _NItem(
          Icons.check_circle_rounded,
          'Upload Complete',
          'Photo upload for School C completed (1,248 photos)',
          AppColors.success,
          false,
          '3h ago'),
      _NItem(
          Icons.pending_rounded,
          'Proof Pending',
          'New proof awaiting approval for School D',
          AppColors.accent,
          true,
          '5h ago'),
      _NItem(
          Icons.payment_rounded,
          'Payment Received',
          '₹62,400 received for ORD-2025-041',
          AppColors.success,
          false,
          '1d ago'),
      _NItem(
          Icons.person_add_rounded,
          'New Client Added',
          'Sunrise Academy added as a new client',
          AppColors.primary,
          false,
          '2d ago'),
    ];

    final filtered =
        filter == 'unread' ? items.where((n) => n.unread).toList() : items;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final n = filtered[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: n.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(n.icon, color: n.color, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(n.title,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: n.unread ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
              if (n.unread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.body, style: AppTypography.bodySmall, maxLines: 2),
              const SizedBox(height: 4),
              Text(n.time,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  )),
            ],
          ),
          onTap: () => context.go('/notifications/detail'),
        ).animate().fadeIn(delay: (i * 40).ms);
      },
    );
  }
}

class _NItem {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final bool unread;
  final String time;
  const _NItem(
      this.icon, this.title, this.body, this.color, this.unread, this.time);
}

// ═══════════════════════════════════════════════════════════════════
// ACTIVITY FEED
// ═══════════════════════════════════════════════════════════════════
class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      (
        'You',
        'uploaded 1,248 student photos',
        '2m ago',
        Icons.upload_rounded,
        AppColors.primary
      ),
      (
        'System',
        'validated data for School A',
        '15m ago',
        Icons.fact_check_rounded,
        AppColors.success
      ),
      (
        'Principal Sharma',
        'approved proof for School A',
        '1h ago',
        Icons.approval_rounded,
        AppColors.success
      ),
      (
        'You',
        'created order ORD-2025-042',
        '3h ago',
        Icons.add_circle_rounded,
        AppColors.primary
      ),
      (
        'Designer Kavya',
        'submitted proof for School B',
        '5h ago',
        Icons.send_rounded,
        AppColors.roleDesigner
      ),
      (
        'System',
        'detected 6 duplicate records',
        '8h ago',
        Icons.warning_rounded,
        AppColors.warning
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: activities.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: 68),
        child: Container(
          height: 24,
          width: 2,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      itemBuilder: (context, i) {
        final a = activities[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: a.$5.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(a.$4, color: a.$5, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                            text: '${a.$1} ',
                            style: AppTypography.labelMedium.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurface)),
                        TextSpan(
                            text: a.$2,
                            style: AppTypography.bodyMedium.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(a.$3,
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION DETAIL
// ═══════════════════════════════════════════════════════════════════
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.approval_rounded,
                    color: AppColors.success, size: 36),
              ),
            ),
            const SizedBox(height: 20),
            Text('Proof Approved',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Principal has approved your design proof',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Details', style: AppTypography.titleSmall),
                  const SizedBox(height: 12),
                  ...[
                    ('Project', 'School A – Batch 2025'),
                    ('Approved by', 'Principal R. Sharma'),
                    ('Time', 'Mar 5, 2025 – 11:42 AM'),
                    ('Next Step', 'Proceed to Printing'),
                  ].map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r.$1,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                )),
                            Text(r.$2, style: AppTypography.labelMedium),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
