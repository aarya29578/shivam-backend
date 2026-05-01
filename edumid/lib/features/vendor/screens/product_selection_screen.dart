import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class ProductSelectionScreen extends StatefulWidget {
  /// Pass the already-selected product id to pre-highlight it.
  final String? preselectedId;

  const ProductSelectionScreen({super.key, this.preselectedId});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.preselectedId;
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        setState(() {
          _loading = false;
          _error = 'No internet connection';
        });
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final res = await dio.get('/api/vendor/products');
      final data = ((res.data as Map<String, dynamic>?)?['data']) as List?;
      if (mounted) {
        setState(() {
          _products = (data ?? [])
              .map((j) => Product.fromJson(j as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } on DioException catch (e) {
      debugPrint('API ERROR: ${e.response?.statusCode}');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Server error. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _select(Product p) {
    setState(() => _selectedId = p.id);
    Navigator.of(context).pop(p);
  }

  Future<void> _openDetail(Product p) async {
    final result = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: p, role: 'vendor'),
      ),
    );
    if (result != null && mounted) _select(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Product'),
        actions: [
          if (_selectedId != null)
            TextButton(
              onPressed: () {
                final product =
                    _products.where((p) => p.id == _selectedId).firstOrNull;
                if (product != null) Navigator.of(context).pop(product);
              },
              child: const Text('Done'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Could not load products', style: AppTypography.titleSmall),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.bodySmall
                    .copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No products found',
                  style: AppTypography.titleSmall
                      .copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Text('Add products via the Admin Portal.',
                  style: AppTypography.bodySmall
                      .copyWith(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _products.length,
      itemBuilder: (context, i) {
        final p = _products[i];
        return _ProductCard(
          product: p,
          selected: _selectedId == p.id,
          role: 'vendor',
          onTap: () => _select(p),
          onDetail: () => _openDetail(p),
        );
      },
    );
  }
}

// ── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool selected;
  final String role;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  const _ProductCard({
    required this.product,
    required this.selected,
    required this.role,
    required this.onTap,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images.isNotEmpty
        ? product.images.first
        : product.thumbnailImage;
    final price = product.priceForRole(role);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.07)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                          )
                        : _placeholder(),
                    // Info button — opens detail screen
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onDetail,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : null,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 18),
                ],
              ),
            ),
            if (price > 0)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 8),
                child: Text(
                  '₹${price.toStringAsFixed(0)} / card',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.secondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.07),
      child: const Center(
        child:
            Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 36),
      ),
    );
  }
}
