import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'logout_helper.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Persists which role-home was last visited so shared routes (orders,
  // notifications, profile) can still reflect the correct role.
  String _activeRoleHome = '/student';

  // Derives the active nav index from the current route path so the
  // highlight never desynchronises from the actual location.
  int _activeIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/orders')) return 1;
    if (path.startsWith('/notifications')) return 3;
    if (path.startsWith('/profile')) return 4;
    return 0; // student / teacher / vendor home all map to index 0
  }

  // Keeps _activeRoleHome in sync when on a role-specific path.
  // Called at the start of build so shared routes inherit the last known role.
  void _syncRoleHome(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/teacher'))
      _activeRoleHome = '/teacher';
    else if (path.startsWith('/vendor'))
      _activeRoleHome = '/vendor';
    else if (path.startsWith('/student')) _activeRoleHome = '/student';
    // shared routes (/orders, /notifications, /profile) → keep last value
  }

  // Returns the correct Home route for whichever role is currently active.
  String _homeRoute(BuildContext context) => _activeRoleHome;

  static final List<_NavItem> _items = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'Projects',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    _NavItem(
      label: 'Upload',
      icon: Icons.cloud_upload_outlined,
      selectedIcon: Icons.cloud_upload_rounded,
    ),
    _NavItem(
      label: 'Alerts',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outlined,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _syncRoleHome(context); // update role before building FAB

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // When user presses back on a root dashboard, show logout confirmation
        // instead of popping out of the app / back to login.
        final nav = Navigator.of(context);
        if (!nav.canPop()) {
          await LogoutHelper.logout(context);
        }
      },
      child: Scaffold(
        body: widget.child,
        floatingActionButton: _buildFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface1Dark : AppColors.surfaceLight,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1,
              ),
            ),
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
                children: [
                  for (int i = 0; i < _items.length; i++)
                    if (_activeRoleHome == '/student' && (i == 1 || i == 2))
                      // For students: skip Projects (1) and FAB placeholder (2)
                      const SizedBox.shrink()
                    else if (i == 2)
                      // FAB centre placeholder for non-student roles
                      const Expanded(child: SizedBox())
                    else
                      Expanded(
                        child: _NavBarItem(
                          item: _items[i],
                          isSelected: _activeIndex(context) == i,
                          onTap: () => _onNavTap(i, context),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    // Hide the FAB (upload button) for the Student role across all tabs.
    if (_activeRoleHome == '/student') return null;
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
          onTap: () => _onNavTap(2, context),
          child: const Icon(
            Icons.cloud_upload_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  void _onNavTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(_homeRoute(context)); // preserves the active role
        break;
      case 1:
        context.go('/orders');
        break;
      case 2:
        _showUploadSheet(context);
        break;
      case 3:
        context.go('/notifications');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _UploadBottomSheet(),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.45);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? item.selectedIcon : item.icon,
              key: ValueKey(isSelected),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadBottomSheet extends StatelessWidget {
  const _UploadBottomSheet();

  @override
  Widget build(BuildContext context) {
    final items = [
      _UploadOption(
        icon: Icons.table_chart_rounded,
        label: 'Upload Excel Data',
        subtitle: 'Import student data from Excel/CSV',
        color: AppColors.success,
        route: '/operator/excel-upload',
      ),
      _UploadOption(
        icon: Icons.photo_library_rounded,
        label: 'Upload Photos',
        subtitle: 'Bulk import student photos',
        color: AppColors.secondary,
        route: '/vendor/create-order/upload-photos',
      ),
      _UploadOption(
        icon: Icons.badge_rounded,
        label: 'Upload ID Template',
        subtitle: 'Import a new card template',
        color: AppColors.accent,
        route: '/designer/assigned',
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
          const SizedBox(height: 20),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.route);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.color.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label, style: AppTypography.labelLarge),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
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
                      Icon(
                        Icons.chevron_right_rounded,
                        color: item.color.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadOption {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}
