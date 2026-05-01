import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// ORDER LIST
// ═══════════════════════════════════════════════════════════════════
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: List.generate(
          4,
          (tabI) => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 8,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final stages = [
                'Printing',
                'Design',
                'Draft',
                'Delivered',
                'Dispatch',
                'Data Upload',
                'Printing',
                'Delivered'
              ];
              final colors = [
                AppColors.primary,
                AppColors.roleDesigner,
                AppColors.warning,
                AppColors.success,
                AppColors.secondary,
                AppColors.roleDataOperator,
                AppColors.primary,
                AppColors.success
              ];
              return PremiumCard(
                onTap: () => context.go('/orders/ORD-2025-0${40 + i}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ORD-2025-0${40 + i}',
                            style: AppTypography.labelLarge),
                        RoleBadge(label: stages[i], color: colors[i]),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('School ${String.fromCharCode(65 + i)} – Batch 2025',
                        style: AppTypography.bodyMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: [
                                0.62,
                                0.45,
                                0.1,
                                1.0,
                                0.85,
                                0.22,
                                0.6,
                                1.0
                              ][i],
                              minHeight: 5,
                              color: colors[i],
                              backgroundColor: colors[i].withOpacity(0.1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${([62, 45, 10, 100, 85, 22, 60, 100][i])}%',
                          style: AppTypography.labelSmall
                              .copyWith(color: colors[i]),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 50).ms);
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ORDER DETAILS
// ═══════════════════════════════════════════════════════════════════
class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(orderId),
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline_rounded),
            onPressed: () => context.go('/orders/$orderId/timeline'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GradientCard(
              gradient: AppColors.primaryGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(orderId,
                          style: AppTypography.titleSmall.copyWith(
                            color: Colors.white,
                          )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Printing',
                            style: AppTypography.labelSmall
                                .copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Delhi Public School – Batch 2025',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      )),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _OrderFact('Total Cards', '1,248'),
                      _OrderFact('Completed', '780'),
                      _OrderFact('Amount', '₹62,400'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Info', style: AppTypography.titleSmall),
                  const SizedBox(height: 12),
                  ...[
                    ('Order Date', 'Mar 1, 2025'),
                    ('Expected Delivery', 'Mar 14, 2025'),
                    ('Tracking Number', 'TRK-24-857432'),
                    ('Vendor', 'Print Solutions Ltd.'),
                    ('School', 'Delhi Public School'),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/orders/$orderId/tracking'),
                    icon: const Icon(Icons.local_shipping_rounded, size: 18),
                    label: const Text('Track'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/orders/$orderId/status'),
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text('Status'),
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

class _OrderFact extends StatelessWidget {
  final String label;
  final String value;
  const _OrderFact(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTypography.titleSmall.copyWith(color: Colors.white)),
          Text(label,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withOpacity(0.6),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCTION STATUS
// ═══════════════════════════════════════════════════════════════════
class ProductionStatusScreen extends StatelessWidget {
  final String orderId;
  const ProductionStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Status – $orderId')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Big progress circle
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('62%',
                          style: AppTypography.displaySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      Text('Complete',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          )),
                    ],
                  ),
                ),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                    child: StatCard(
                        title: 'Printed',
                        value: '780',
                        icon: Icons.print_rounded,
                        color: AppColors.success)),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        title: 'Remaining',
                        value: '468',
                        icon: Icons.pending_rounded,
                        color: AppColors.warning)),
              ],
            ),
            const SizedBox(height: 20),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By Class', style: AppTypography.titleSmall),
                  const SizedBox(height: 12),
                  ...[
                    ('Class VI', 0.95),
                    ('Class VII', 0.88),
                    ('Class VIII', 0.72),
                    ('Class IX', 0.45),
                    ('Class X', 0.28),
                  ].map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(r.$1, style: AppTypography.labelSmall),
                                Text('${(r.$2 * 100).toInt()}%',
                                    style: AppTypography.labelSmall
                                        .copyWith(color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: r.$2,
                                minHeight: 5,
                                color: AppColors.primary,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.1),
                              ),
                            ),
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

// ═══════════════════════════════════════════════════════════════════
// PRODUCTION TIMELINE
// ═══════════════════════════════════════════════════════════════════
class ProductionTimelineScreen extends StatelessWidget {
  final String orderId;
  const ProductionTimelineScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Order Placed', 'Mar 1, 2025', true, false),
      ('Data Uploaded', 'Mar 2, 2025', true, false),
      ('Photos Matched', 'Mar 3, 2025', true, false),
      ('Design Selected', 'Mar 4, 2025', true, false),
      ('Proof Approved', 'Mar 5, 2025', true, false),
      ('Printing', 'In Progress', false, true),
      ('Quality Check', 'Estimated Mar 12', false, false),
      ('Dispatch', 'Estimated Mar 13', false, false),
      ('Delivery', 'Estimated Mar 14', false, false),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Timeline – $orderId')),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: steps.length,
        itemBuilder: (context, i) {
          final s = steps[i];
          return ProgressStep(
            label: '${s.$1} • ${s.$2}',
            isCompleted: s.$3,
            isCurrent: s.$4,
            isLast: i == steps.length - 1,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SHIPMENT TRACKING
// ═══════════════════════════════════════════════════════════════════
class ShipmentTrackingScreen extends StatelessWidget {
  final String orderId;
  const ShipmentTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tracking – $orderId')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GradientCard(
              gradient: AppColors.secondaryGradient,
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 36),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRK-24-857432',
                          style: AppTypography.titleSmall.copyWith(
                            color: Colors.white,
                          )),
                      Text('In Transit – Est. Mar 14',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tracking Events', style: AppTypography.titleSmall),
                  const SizedBox(height: 16),
                  ...[
                    ('Out for Delivery', 'Mar 13, 2:30 PM', true),
                    ('Reached Hub – Delhi', 'Mar 13, 8:00 AM', true),
                    ('Dispatched from Warehouse', 'Mar 11, 4:00 PM', true),
                    ('Packed', 'Mar 10, 11:00 AM', true),
                  ].asMap().entries.map(
                        (e) => ProgressStep(
                          label: '${e.value.$1} • ${e.value.$2}',
                          isCompleted: e.value.$3,
                          isCurrent: e.key == 0,
                          isLast: e.key == 3,
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
}

// ═══════════════════════════════════════════════════════════════════
// DELIVERY CONFIRMATION
// ═══════════════════════════════════════════════════════════════════
class DeliveryConfirmationScreen extends StatefulWidget {
  final String orderId;
  const DeliveryConfirmationScreen({super.key, required this.orderId});

  @override
  State<DeliveryConfirmationScreen> createState() =>
      _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState
    extends State<DeliveryConfirmationScreen> {
  bool _loading = false;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 60),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text('Delivery Confirmed!', style: AppTypography.headlineMedium)
                  .animate()
                  .fadeIn(delay: 400.ms),
              const SizedBox(height: 12),
              Text('All 1,248 ID cards delivered successfully.',
                      style: AppTypography.bodyMedium)
                  .animate()
                  .fadeIn(delay: 600.ms),
              const SizedBox(height: 40),
              GradientButton(
                label: 'Back to Orders',
                onPressed: () => context.go('/orders'),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Confirm Delivery – ${widget.orderId}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery Summary', style: AppTypography.titleSmall),
                  const SizedBox(height: 12),
                  _DelivRow('Order', widget.orderId),
                  _DelivRow('School', 'Delhi Public School'),
                  _DelivRow('Cards', '1,248'),
                  _DelivRow('Delivered by', 'BlueDart (TRK-24-857432)'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Confirmation Photo', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            GestureDetector(
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primary.withOpacity(0.04),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded,
                        size: 36, color: AppColors.primary),
                    SizedBox(height: 8),
                    Text('Take/Upload Photo'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            GradientButton(
              label: 'Confirm Delivery',
              loading: _loading,
              onPressed: () async {
                setState(() => _loading = true);
                await Future.delayed(const Duration(seconds: 1));
                setState(() {
                  _loading = false;
                  _confirmed = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DelivRow extends StatelessWidget {
  final String label;
  final String value;
  const _DelivRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              )),
          Text(value, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}
