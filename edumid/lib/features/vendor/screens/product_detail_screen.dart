import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/product.dart';
import '../../../core/api/api_config.dart';

/// Full-screen product detail shown when tapping a product card.
/// [role] controls which price is highlighted (defaults to 'vendor').
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String role;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.role = 'vendor',
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _activeImage = 0;
  late final PageController _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  static const _roleLabels = {
    'vendor': 'Vendor',
    'client': 'Client',
    'public': 'Public',
    'principal': 'Principal',
    'student': 'Student',
  };

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.images;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded),
            tooltip: 'Select this product',
            onPressed: () => Navigator.of(context).pop(product),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image viewer ───────────────────────────────────────
            if (images.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _activeImage = i),
                  itemBuilder: (context, i) => Image.network(
                    ApiConfig.resolveImageUrl(images[i]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              if (images.length > 1) ...[
                const SizedBox(height: 8),
                // Dot indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == _activeImage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                // Thumbnail strip
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final active = i == _activeImage;
                      return GestureDetector(
                        onTap: () {
                          _pageCtrl.animateToPage(i,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              ApiConfig.resolveImageUrl(images[i]),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _imagePlaceholder(small: true),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _imagePlaceholder(),
              ),

            // ── Product info ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + category
                  Text(product.name, style: AppTypography.headlineSmall),
                  if (product.category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.category,
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Pricing table ─────────────────────────────────
                  _SectionHeader(title: 'Pricing by Role'),
                  const SizedBox(height: 12),
                  _PricingTable(
                    pricing: product.pricing,
                    activeRole: widget.role,
                    roleLabels: _roleLabels,
                  ),
                  const SizedBox(height: 24),

                  // ── Description ───────────────────────────────────
                  if (product.description.isNotEmpty) ...[
                    _SectionHeader(title: 'Description'),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: AppTypography.bodyMedium
                          .copyWith(color: Colors.grey.shade700, height: 1.55),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(product),
            child: const Text('Select this Product'),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder({bool small = false}) {
    return Container(
      color: AppColors.primary.withOpacity(0.07),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: AppColors.primary.withOpacity(0.4),
          size: small ? 24 : 56,
        ),
      ),
    );
  }
}

// ── Pricing table ─────────────────────────────────────────────────────────────

class _PricingTable extends StatelessWidget {
  final Map<String, double> pricing;
  final String activeRole;
  final Map<String, String> roleLabels;

  const _PricingTable({
    required this.pricing,
    required this.activeRole,
    required this.roleLabels,
  });

  @override
  Widget build(BuildContext context) {
    final entries = pricing.entries
        .where((e) => e.value > 0 || e.key == activeRole)
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final isActive = entry.key == activeRole;
          final label = roleLabels[entry.key] ?? entry.key;
          return Container(
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(11) : Radius.zero,
                bottom: i == entries.length - 1
                    ? const Radius.circular(11)
                    : Radius.zero,
              ),
              border: i > 0
                  ? Border(top: BorderSide(color: Colors.grey.shade200))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (isActive)
                  const Icon(Icons.person_rounded,
                      size: 16, color: AppColors.primary)
                else
                  const Icon(Icons.person_outline_rounded,
                      size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: isActive ? AppColors.primary : null,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  entry.value > 0 ? '₹${entry.value.toStringAsFixed(2)}' : '—',
                  style: AppTypography.labelMedium.copyWith(
                    color: isActive ? AppColors.primary : Colors.grey.shade700,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'YOUR PRICE',
                      style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style:
                AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
