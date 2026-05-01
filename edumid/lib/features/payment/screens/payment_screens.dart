import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// WALLET SCREEN
// ═══════════════════════════════════════════════════════════════════
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Balance card
            GradientCard(
              gradient: AppColors.primaryGradient,
              child: Column(
                children: [
                  Text('Wallet Balance',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      )),
                  const SizedBox(height: 8),
                  Text('₹1,24,800',
                      style: AppTypography.displayMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WalletAction(
                        icon: Icons.add_rounded,
                        label: 'Add Funds',
                        onTap: () => context.go('/payment/add-funds'),
                      ),
                      const SizedBox(width: 16),
                      _WalletAction(
                        icon: Icons.account_balance_rounded,
                        label: 'Payment Methods',
                        onTap: () => context.go('/payment/methods'),
                      ),
                      const SizedBox(width: 16),
                      _WalletAction(
                        icon: Icons.history_rounded,
                        label: 'History',
                        onTap: () => context.go('/payment/history'),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent Transactions',
              action: 'See All',
              onAction: () => context.go('/payment/history'),
            ),
            const SizedBox(height: 12),
            ..._transactions.map((t) => _TransactionTile(tx: t)),
          ],
        ),
      ),
    );
  }
}

final _transactions = [
  _Tx('Order ORD-2025-042', '−₹62,400', 'Mar 1, 2025', false, AppColors.error),
  _Tx('Funds Added', '+₹1,00,000', 'Feb 28, 2025', true, AppColors.success),
  _Tx('Order ORD-2025-039', '−₹38,250', 'Feb 20, 2025', false, AppColors.error),
  _Tx('Refund – ORD-038', '+₹4,200', 'Feb 15, 2025', true, AppColors.success),
  _Tx('Order ORD-2025-037', '−₹52,000', 'Feb 10, 2025', false, AppColors.error),
];

class _Tx {
  final String label;
  final String amount;
  final String date;
  final bool credit;
  final Color color;
  const _Tx(this.label, this.amount, this.date, this.credit, this.color);
}

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _WalletAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withOpacity(0.8),
              )),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final _Tx tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tx.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tx.credit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: tx.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label, style: AppTypography.labelMedium),
                Text(tx.date, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Text(tx.amount,
              style: AppTypography.labelLarge.copyWith(color: tx.color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADD FUNDS
// ═══════════════════════════════════════════════════════════════════
class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key});

  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
  String _selected = '₹10,000';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Funds')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Amount', style: AppTypography.titleSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['₹5,000', '₹10,000', '₹25,000', '₹50,000', '₹1,00,000']
                  .map((a) => GestureDetector(
                        onTap: () => setState(() => _selected = a),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selected == a
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            a,
                            style: AppTypography.labelMedium.copyWith(
                              color: _selected == a
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const AppTextField(
              label: 'Custom Amount',
              hint: 'Enter amount (₹)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Text('Payment Method', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            PremiumCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HDFC Bank – ****4532',
                            style: AppTypography.labelMedium),
                        Text('Savings Account', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary),
                ],
              ),
            ),
            const Spacer(),
            GradientButton(
              label: 'Add $_selected',
              loading: _loading,
              onPressed: () async {
                setState(() => _loading = true);
                await Future.delayed(const Duration(seconds: 1));
                if (context.mounted) {
                  setState(() => _loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$_selected added to wallet!')),
                  );
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAYMENT METHOD
// ═══════════════════════════════════════════════════════════════════
class PaymentMethodScreen extends StatelessWidget {
  const PaymentMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Bank Accounts', style: AppTypography.titleSmall),
          const SizedBox(height: 12),
          ...[
            (
              'HDFC Bank',
              '****4532',
              'Savings Account',
              Icons.account_balance_rounded,
              true
            ),
            (
              'SBI',
              '****8821',
              'Current Account',
              Icons.account_balance_rounded,
              false
            ),
          ].map((b) => PremiumCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(b.$4, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b.$1} – ${b.$2}',
                              style: AppTypography.labelMedium),
                          Text(b.$3, style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    if (b.$5)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary),
                  ],
                ),
              )),
          const SizedBox(height: 20),
          Text('UPI', style: AppTypography.titleSmall),
          const SizedBox(height: 12),
          PremiumCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('vendor@hdfc', style: AppTypography.labelMedium),
                      Text('UPI ID', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRANSACTION HISTORY
// ═══════════════════════════════════════════════════════════════════
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Spent',
                    value: '₹2.4L',
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Total Added',
                    value: '₹3.0L',
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _transactions.length * 2,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final tx = _transactions[i % _transactions.length];
                return _TransactionTile(tx: tx);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INVOICE
// ═══════════════════════════════════════════════════════════════════
class InvoiceScreen extends StatelessWidget {
  final String? orderId;
  const InvoiceScreen({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice${orderId != null ? ' – $orderId' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('INVOICE',
                          style: AppTypography.headlineMedium
                              .copyWith(color: AppColors.primary)),
                      Text('#INV-2025-042', style: AppTypography.titleSmall),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.primary)),
                            Text('Print Solutions Ltd.',
                                style: AppTypography.labelMedium),
                            Text('Delhi, India',
                                style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.primary)),
                            Text('Delhi Public School',
                                style: AppTypography.labelMedium),
                            Text('New Delhi, India',
                                style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...[
                    ('Standard ID Cards × 1,248', '₹56,160'),
                    ('Lamination', '₹3,120'),
                    ('Delivery', '₹800'),
                    ('GST (18%)', ''),
                  ].map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r.$1, style: AppTypography.bodyMedium),
                            Text(r.$2, style: AppTypography.labelMedium),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppTypography.titleSmall),
                      Text('₹62,400',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.primary,
                          )),
                    ],
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
