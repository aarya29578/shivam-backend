import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/logout_helper.dart';

/// Bottom navigation shell for the Student role.
///
/// Nav items:  Home (0) | Alerts (1) | Profile (2)
///
/// All paths route exclusively within the /student tree.
class StudentShell extends StatelessWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  static const _blue = AppColors.primary;

  int _activeTab(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/student/attendance')) return 1;
    if (path.startsWith('/student/profile')) return 2;
    return 0; // home + all id-card / vcard sub-screens
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
        bottomNavigationBar: _StudentBottomNav(
          activeTab: tab,
          isDark: isDark,
          color: _blue,
          onTap: (i) => _handleTap(i, context),
        ),
      ),
    );
  }

  void _handleTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/student');
        return;
      case 1:
        context.go('/student/attendance');
        return;
      case 2:
        context.go('/student/profile');
        return;
    }
  }
}

// ── Bottom Nav ──────────────────────────────────────────────────────

class _StudentBottomNav extends StatelessWidget {
  final int activeTab;
  final bool isDark;
  final Color color;
  final ValueChanged<int> onTap;

  const _StudentBottomNav({
    required this.activeTab,
    required this.isDark,
    required this.color,
    required this.onTap,
  });

  static const _items = [
    _NavDef('Home', Icons.home_outlined, Icons.home_rounded),
    _NavDef('Attendance', Icons.calendar_month_outlined, Icons.calendar_month),
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
