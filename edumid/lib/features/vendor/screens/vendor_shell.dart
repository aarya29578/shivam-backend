import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/logout_helper.dart';
import 'vendor_screens.dart' show vendorDashboardRefreshTrigger;
import 'quick_capture_screen.dart' show QuickCaptureSetupScreen;

/// Bottom navigation shell for the Vendor role.
///
/// Nav items:  Home (0) | Projects (1) | Upload FAB (2) | Alerts (3) | Profile (4)
///
/// All paths route exclusively within the /vendor tree.
class VendorShell extends StatelessWidget {
  final Widget child;
  const VendorShell({super.key, required this.child});

  static const _indigo = AppColors.primary;

  int _activeTab(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/vendor/project-board')) return 1;
    if (path.startsWith('/vendor/notifications')) return 3;
    if (path.startsWith('/vendor/profile')) return 4;
    return 0; // home / clients / orders / upload-excel all map to home
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tab = _activeTab(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!Navigator.of(context).canPop()) {
          await LogoutHelper.logout(context);
        }
      },
      child: Scaffold(
        body: child,
        floatingActionButton: _buildFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _VendorBottomNav(
          activeTab: tab,
          isDark: isDark,
          color: _indigo,
          onTap: (i) => _handleTap(i, context),
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _showUploadSheet(context),
          child: const Icon(
            Icons.cloud_upload_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  void _handleTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        vendorDashboardRefreshTrigger.value++;
        context.go('/vendor');
      case 1:
        context.go('/vendor/project-board');
      case 2:
        _showUploadSheet(context);
      case 3:
        context.go('/vendor/notifications');
      case 4:
        context.go('/vendor/profile');
    }
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _VendorUploadSheet(),
    );
  }
}

// ── Bottom Nav ──────────────────────────────────────────────────────

class _VendorBottomNav extends StatelessWidget {
  final int activeTab;
  final bool isDark;
  final Color color;
  final ValueChanged<int> onTap;

  const _VendorBottomNav({
    required this.activeTab,
    required this.isDark,
    required this.color,
    required this.onTap,
  });

  static const _items = [
    _NavDef('Home', Icons.home_outlined, Icons.home_rounded),
    _NavDef('Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _NavDef('Upload', Icons.cloud_upload_outlined,
        Icons.cloud_upload_rounded), // FAB placeholder slot
    _NavDef(
        'Alerts', Icons.notifications_outlined, Icons.notifications_rounded),
    _NavDef('Profile', Icons.person_outlined, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surface1Dark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              if (i == 2) {
                // Centre FAB reserved slot
                return const Expanded(child: SizedBox());
              }
              final def = _items[i];
              final sel = activeTab == i;
              final c = sel
                  ? color
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.45);
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          sel ? def.activeIcon : def.icon,
                          key: ValueKey(sel),
                          color: c,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        def.label,
                        style: AppTypography.caption.copyWith(
                          color: c,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavDef(this.label, this.icon, this.activeIcon);
}

// ── Upload Bottom Sheet ─────────────────────────────────────────────

class _VendorUploadSheet extends StatelessWidget {
  const _VendorUploadSheet();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.table_chart_rounded,
        'Upload Excel Data',
        'Import student data from Excel/CSV',
        AppColors.success,
        '/vendor/upload-excel',
      ),
      (
        Icons.photo_library_rounded,
        'Upload Photos',
        'Bulk import student photos',
        AppColors.secondary,
        '/vendor/upload-photos',
      ),
      (
        Icons.camera_alt_rounded,
        'Quick Capture Mode',
        'Capture student photos on-device',
        AppColors.roleTeacher,
        null, // handled with Navigator.push
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Quick Upload', style: AppTypography.titleMedium),
          Text(
            'Choose what you want to upload',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  if (item.$5 != null) {
                    Navigator.of(context).pop();
                    context.go(item.$5!);
                  } else {
                    // Quick Capture — capture navigator before dismissing sheet
                    final nav = Navigator.of(context, rootNavigator: true);
                    Navigator.of(context).pop();
                    nav.push(MaterialPageRoute(
                      builder: (_) => const QuickCaptureSetupScreen(),
                    ));
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.$4.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: item.$4.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.$4.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.$1, color: item.$4, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: AppTypography.labelLarge),
                          Text(item.$3,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              )),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
