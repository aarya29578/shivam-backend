import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/order_request_store.dart';
import '../../../shared/models/notification_store.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/logout_helper.dart';
import '../../../core/api/api_config.dart';
import '../../reprint/reprint_repository.dart';
import '../../reprint/models/reprint_request.dart';
import '../../teacher/screens/teacher_attendance_extras.dart';
import '../../../shared/widgets/user_profile_screen.dart';
import '../../../shared/widgets/id_card_form_submissions_screen.dart';
import '../../../core/services/id_card_form_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/notice_screens.dart';

// ═══════════════════════════════════════════════════════════════════
// PRINCIPAL SHELL – dedicated nav: Home | Data | Add | Profile
// ═══════════════════════════════════════════════════════════════════

class PrincipalShell extends StatelessWidget {
  final Widget child;
  const PrincipalShell({super.key, required this.child});

  static const _teal = AppColors.primary;

  int _activeTab(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/principal/data')) return 1;
    if (path.startsWith('/principal/attendance')) return 3;
    if (path.startsWith('/principal/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tab = _activeTab(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!nav.canPop()) await LogoutHelper.logout(context);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: _PrincipalBottomNav(
          activeTab: tab,
          isDark: isDark,
          teal: _teal,
          onTap: (i) => _handleTap(i, context),
        ),
      ),
    );
  }

  void _handleTap(int i, BuildContext context) {
    switch (i) {
      case 0:
        context.go('/principal');
      case 1:
        context.go('/principal/data');
      case 2:
        _showAddSheet(context);
      case 3:
        context.go('/principal/attendance');
      case 4:
        context.go('/principal/profile');
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PrincipalAddBottomSheet(parentContext: context),
    );
  }
}

// ── Bottom Nav Bar ──────────────────────────────────────────────────

class _PrincipalBottomNav extends StatelessWidget {
  final int activeTab;
  final bool isDark;
  final Color teal;
  final ValueChanged<int> onTap;
  const _PrincipalBottomNav({
    required this.activeTab,
    required this.isDark,
    required this.teal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surface1Dark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    // 5 items:  Home(0) | Data(1) | Add(2-center) | Attendance(3) | Profile(4)
    final items = [
      _NavDef('Home', Icons.home_outlined, Icons.home_rounded),
      _NavDef('Data', Icons.analytics_outlined, Icons.analytics_rounded),
      _NavDef('Add', Icons.add_rounded, Icons.add_rounded), // center FAB
      _NavDef(
          'Attendance', Icons.fact_check_outlined, Icons.fact_check_rounded),
      _NavDef('Profile', Icons.person_outlined, Icons.person_rounded),
    ];

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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: List.generate(items.length, (i) {
                  // Reserve space for center FAB slot
                  if (i == 2) return const Expanded(child: SizedBox());
                  final def = items[i];
                  final sel = activeTab == i;
                  final color = sel
                      ? teal
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45);
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
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            def.label,
                            style: AppTypography.caption.copyWith(
                              color: color,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              // -- Centered elevated FAB -------------------------
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: GestureDetector(
                      onTap: () => onTap(2),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [teal, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: teal.withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

// ── FAB ─────────────────────────────────────────────────────────────

// ── Add Bottom Sheet ─────────────────────────────────────────────────

class _PrincipalAddBottomSheet extends StatelessWidget {
  final BuildContext parentContext;
  const _PrincipalAddBottomSheet({required this.parentContext});

  void _showForm(Widget form) {
    Navigator.of(parentContext).pop();
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => form,
    );
  }

  @override
  Widget build(BuildContext context) {
    final opts = [
      (
        Icons.class_,
        'Add Class',
        'Create a class / section',
        AppColors.secondary,
        () => _showForm(const _AddClassSheet()),
      ),
      (
        Icons.person_add_alt_1_rounded,
        'Add Teacher',
        'Register a teaching staff member',
        AppColors.roleTeacher,
        () => _showForm(const _AddTeacherSheet()),
      ),
      (
        Icons.school_rounded,
        'Add Student',
        'Enroll a new student',
        AppColors.primary,
        () => _showForm(const _AddStudentSheet()),
      ),
      (
        Icons.badge_rounded,
        'Add Staff',
        'Add non-teaching staff member',
        AppColors.accent,
        () => _showForm(const _AddStaffSheet()),
      ),
      (
        Icons.campaign_rounded,
        'Add Notice',
        'Create and share a school notice',
        AppColors.warning,
        () {
          Navigator.of(parentContext).pop();
          Navigator.of(parentContext).push(
            MaterialPageRoute(
              builder: (_) => const CreateNoticeScreen(),
            ),
          );
        },
      ),
      (
        Icons.assignment_ind_rounded,
        'Assign Class to Teacher',
        'Map a class & section to a teacher',
        AppColors.roleTeacher,
        () => _showForm(const _AssignClassToTeacherSheet()),
      ),
      (
        Icons.description_rounded,
        'View Form Submissions',
        'See all filled form responses',
        Color(0xFF059669),
        () {
          Navigator.of(parentContext).pop();
          Navigator.of(parentContext).push(
            MaterialPageRoute(
              builder: (_) => IdCardFormSubmissionsScreen(
                principalId: _kPrincipalId,
              ),
            ),
          );
        },
      ),
    ];

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add to School', style: AppTypography.titleMedium),
                Text(
                  'What would you like to create?',
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 20),
            ...opts.asMap().entries.map((e) {
              final (icon, label, sub, color, onTap) = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.18)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: AppTypography.labelLarge),
                            Text(
                              sub,
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
                      Icon(Icons.chevron_right_rounded,
                          color: color.withOpacity(0.6)),
                    ]),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 40 * e.key))
                    .fadeIn(duration: 200.ms)
                    .slideX(begin: 0.05, end: 0),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Add Form Sheets ──────────────────────────────────────────────────

// ── Assign Class to Teacher Sheet ──────────────────────────────────

class _AssignClassToTeacherSheet extends StatefulWidget {
  const _AssignClassToTeacherSheet();
  @override
  State<_AssignClassToTeacherSheet> createState() =>
      _AssignClassToTeacherSheetState();
}

class _AssignClassToTeacherSheetState
    extends State<_AssignClassToTeacherSheet> {
  static const _teacherRoles = ['Class Teacher', 'Subject Teacher'];

  String? _selectedClass;
  String? _selectedTeacherRole;
  String? _selectedTeacherName;

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : onSurface.withOpacity(0.25),
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? color : onSurface.withOpacity(0.75),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool get _canSave =>
      _selectedTeacherName != null &&
      _selectedClass != null &&
      _selectedTeacherRole != null;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.roleTeacher;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final store = SchoolDataStore.instance;
    final liveClasses = store.classes;
    final liveTeachers = store.teachers;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(Icons.assignment_ind_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Assign Class to Teacher',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 24),

            // ── Select Teacher ──────────────────────────────────────
            Text('Select Teacher',
                style: AppTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            liveTeachers.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: color.withOpacity(0.6)),
                      const SizedBox(width: 10),
                      Text('No teachers added yet',
                          style: AppTypography.bodySmall
                              .copyWith(color: onSurface.withOpacity(0.5))),
                    ]),
                  )
                : Column(
                    children: liveTeachers.map((t) {
                      final selected = _selectedTeacherName == t.name;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedTeacherName = t.name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withOpacity(0.08)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : onSurface.withOpacity(0.15),
                                width: selected ? 1.8 : 1.2,
                              ),
                            ),
                            child: Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      color.withOpacity(selected ? 0.18 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    t.name.isNotEmpty ? t.name[0] : '?',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.name,
                                        style:
                                            AppTypography.labelMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: selected ? color : null,
                                        )),
                                    Text(t.classOrDept,
                                        style: AppTypography.bodySmall.copyWith(
                                            color: onSurface.withOpacity(0.5))),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: color, size: 20),
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),

            // ── Teacher Role ────────────────────────────────────────
            Text('Teacher Role',
                style: AppTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _teacherRoles
                  .map((r) => _chip(
                        label: r,
                        selected: _selectedTeacherRole == r,
                        color: color,
                        onTap: () => setState(() => _selectedTeacherRole = r),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ── Select Class (from store) ────────────────────────────
            Text('Select Class',
                style: AppTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            liveClasses.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: color.withOpacity(0.6)),
                      const SizedBox(width: 10),
                      Text('No classes added yet',
                          style: AppTypography.bodySmall
                              .copyWith(color: onSurface.withOpacity(0.5))),
                    ]),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: liveClasses
                        .map((c) => _chip(
                              label: c.name,
                              selected: _selectedClass == c.name,
                              color: color,
                              onTap: () =>
                                  setState(() => _selectedClass = c.name),
                            ))
                        .toList(),
                  ),
            const SizedBox(height: 28),

            // ── Save button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _canSave
                    ? () {
                        final role = _selectedTeacherRole!;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$_selectedTeacherName assigned as $role to '
                              '$_selectedClass',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Assign Class'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: color.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ASSIGN STAFF ROLE SHEET
// ═══════════════════════════════════════════════════════════════════

class _AssignStaffRoleSheet extends StatefulWidget {
  final String staffName;
  final String currentRole;
  const _AssignStaffRoleSheet({
    required this.staffName,
    required this.currentRole,
  });

  @override
  State<_AssignStaffRoleSheet> createState() => _AssignStaffRoleSheetState();
}

class _AssignStaffRoleSheetState extends State<_AssignStaffRoleSheet> {
  static const _roles = [
    'Coordinator',
    'Lab In-charge',
    'Librarian',
    'Admin',
    'Security',
    'Canteen',
    'Peon',
    'Accountant',
    'Receptionist',
    'Driver',
  ];

  late String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole =
        _roles.contains(widget.currentRole) ? widget.currentRole : null;
  }

  Widget _chip(String label) {
    final sel = _selectedRole == label;
    final color = AppColors.accent;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? color : onSurface.withOpacity(0.25),
            width: sel ? 1.6 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: sel ? color : onSurface.withOpacity(0.75),
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.accent;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.manage_accounts_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assign Staff Role',
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        widget.staffName,
                        style: AppTypography.bodySmall
                            .copyWith(color: onSurface.withOpacity(0.55)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 24),
            Text('Select Role',
                style: AppTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roles.map(_chip).toList(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _selectedRole == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${widget.staffName} assigned as $_selectedRole',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Assign Role'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: color.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCHOOL DATA STORE  (persisted to backend via REST API)
// ═══════════════════════════════════════════════════════════════════

/// Backend base URL – configured globally
/// See: lib/core/api/api_config.dart
const String _kPrincipalBase = ApiConfig.baseUrl;
String _kPrincipalId = '';
const _kPrincipalIdCacheKey = 'principal_id_cache';

/// Clear the in-memory principalId cache so the next [_ensurePrincipalId]
/// call re-reads from SharedPreferences. Call this after login / logout.
void _resetPrincipalIdCache() => _kPrincipalId = '';

Dio _principalDio() => Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
    ));

Future<String> _ensurePrincipalId() async {
  if (_kPrincipalId.isNotEmpty) return _kPrincipalId;

  final prefs = await SharedPreferences.getInstance();

  // 1. Check dedicated principalId cache (survives session token expiry)
  final cached = (prefs.getString(_kPrincipalIdCacheKey) ?? '').trim();
  if (cached.isNotEmpty) {
    _kPrincipalId = cached;
    return _kPrincipalId;
  }

  // 2. Derive from stored user or fresh network profile
  Map<String, dynamic>? user = await AuthService.instance.getStoredUser();
  user ??= await AuthService.instance.getProfile();

  // NOTE: vendor accounts have principalId == '' (empty string, not null).
  // Dart ?? only guards against null, so we must check for empty explicitly.
  String principalId = (user?['principalId']?.toString().trim() ?? '');
  if (principalId.isEmpty) {
    principalId = (user?['id']?.toString().trim() ?? '');
  }

  if (principalId.isNotEmpty) {
    _kPrincipalId = principalId;
    // Persist so we survive token expiry / cold restarts
    await prefs.setString(_kPrincipalIdCacheKey, principalId);
  }
  return _kPrincipalId;
}

class _SchoolClass {
  String id;
  final String name;
  _SchoolClass({required this.id, required this.name});
}

class SchoolDataStore extends ChangeNotifier {
  static final SchoolDataStore instance = SchoolDataStore._();
  SchoolDataStore._() {
    WidgetsBinding.instance.addPostFrameCallback((_) => loadAll());
  }

  bool _loaded = false;
  bool _loading = false;

  final List<_SchoolClass> _classes = [];
  final List<_MemberEntry> _teachers = [];
  final List<_MemberEntry> _students = [];
  final List<_MemberEntry> _staff = [];

  List<_SchoolClass> get classes => List.unmodifiable(_classes);
  List<_MemberEntry> get teachers => List.unmodifiable(_teachers);
  List<_MemberEntry> get students => List.unmodifiable(_students);
  List<_MemberEntry> get staff => List.unmodifiable(_staff);

  int get classCount => _classes.length;
  int get teacherCount => _teachers.length;
  int get studentCount => _students.length;
  int get staffCount => _staff.length;
  bool get isLoading => _loading;

  // ── Load all data from backend ─────────────────────────────────────
  Future<void> loadAll() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final principalId = await _ensurePrincipalId();
      if (principalId.isEmpty) {
        debugPrint('[Principal] ❌ principalId missing in session');
        _loaded = false;
        _loading = false;
        notifyListeners();
        return;
      }

      debugPrint('═' * 60);
      debugPrint('[Principal] Starting loadAll()...');
      debugPrint('Base URL: $_kPrincipalBase');
      debugPrint('Principal ID: $principalId');
      debugPrint('═' * 60);

      final dio = _principalDio();
      final results = await Future.wait([
        dio.get('$_kPrincipalBase/api/principal/classes',
            queryParameters: {'principalId': principalId}),
        dio.get('$_kPrincipalBase/api/principal/members',
            queryParameters: {'principalId': principalId, 'type': 'teacher'}),
        dio.get('$_kPrincipalBase/api/principal/members',
            queryParameters: {'principalId': principalId, 'type': 'student'}),
        dio.get('$_kPrincipalBase/api/principal/members',
            queryParameters: {'principalId': principalId, 'type': 'staff'}),
      ]);

      _classes.clear();
      _teachers.clear();
      _students.clear();
      _staff.clear();

      // Parse classes
      final classesData = results[0].data;
      debugPrint('[Classes Response] Status: ${results[0].statusCode}');
      if (classesData is! List) {
        debugPrint(
            '[Classes] ❌ Expected List, got ${classesData.runtimeType}: $classesData');
      }
      final classList = classesData is List
          ? List<Map<String, dynamic>>.from(classesData)
          : [];
      debugPrint('[Classes Parsed] Count: ${classList.length}');
      for (final c in classList) {
        _classes.add(
            _SchoolClass(id: c['id'].toString(), name: c['name'] as String));
      }

      // Parse teachers
      final teachersData = results[1].data;
      debugPrint('[Teachers Response] Status: ${results[1].statusCode}');
      debugPrint(
          '[Teachers Raw] Type: ${teachersData.runtimeType}, Value: $teachersData');
      final teacherList = teachersData is List
          ? List<Map<String, dynamic>>.from(teachersData)
          : [];
      debugPrint('[Teachers Parsed] Count: ${teacherList.length}');
      for (final t in teacherList) {
        _teachers.add(_MemberEntry(
          id: t['id'].toString(),
          name: t['name'] as String,
          classOrDept: t['classOrDept'] as String? ?? '',
          phone: t['phone'] as String? ?? '',
          address: t['address'] as String? ?? '',
          profileImage: t['profileImage'] as String? ?? '',
        ));
      }

      // Parse students
      final studentsData = results[2].data;
      debugPrint('[Students Response] Status: ${results[2].statusCode}');
      if (studentsData is! List) {
        debugPrint(
            '[Students] ❌ Expected List, got ${studentsData.runtimeType}: $studentsData');
      }
      final studentList = studentsData is List
          ? List<Map<String, dynamic>>.from(studentsData)
          : [];
      debugPrint('[Students Parsed] Count: ${studentList.length}');
      for (final s in studentList) {
        _students.add(_MemberEntry(
          id: s['id'].toString(),
          name: s['name'] as String,
          classOrDept: s['classOrDept'] as String? ?? '',
          phone: s['phone'] as String? ?? '',
          address: s['address'] as String? ?? '',
          profileImage: s['profileImage'] as String? ?? '',
        ));
      }

      // Parse staff
      final staffData = results[3].data;
      debugPrint('[Staff Response] Status: ${results[3].statusCode}');
      debugPrint(
          '[Staff Raw] Type: ${staffData.runtimeType}, Value: $staffData');
      final staffList =
          staffData is List ? List<Map<String, dynamic>>.from(staffData) : [];
      debugPrint('[Staff Parsed] Count: ${staffList.length}');
      for (final st in staffList) {
        _staff.add(_MemberEntry(
          id: st['id'].toString(),
          name: st['name'] as String,
          classOrDept: st['classOrDept'] as String? ?? '',
          phone: st['phone'] as String? ?? '',
          address: st['address'] as String? ?? '',
          profileImage: st['profileImage'] as String? ?? '',
        ));
      }

      _loaded = true;
      debugPrint('═' * 60);
      debugPrint('[Principal] ✅ loadAll() completed successfully');
      debugPrint('═' * 60);
    } catch (e, st) {
      debugPrint('═' * 60);
      debugPrint('[Principal] ❌ loadAll() ERROR: $e');
      debugPrint('Stack Trace: $st');
      debugPrint('═' * 60);
      _loaded = false;
    }
    _loading = false;
    notifyListeners();
  }

  /// Force-refresh all data from the backend.
  Future<void> reload() async {
    _resetPrincipalIdCache(); // always re-read principalId on explicit reload
    _loaded = false;
    _loading = false; // unblock any stuck in-progress load
    await loadAll();
  }

  // ── Add ───────────────────────────────────────────────────────────
  Future<void> addClass(String name) async {
    final entry = _SchoolClass(id: '', name: name);
    _classes.add(entry);
    notifyListeners();
    debugPrint('[Principal] addClass() - Adding class: $name');
    try {
      final res = await _principalDio().post(
        '$_kPrincipalBase/api/principal/classes',
        data: {'name': name, 'principalId': _kPrincipalId},
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        entry.id = res.data['id'].toString();
        debugPrint('[Principal] addClass() - Success! ID: ${entry.id}');
      } else {
        debugPrint(
            '[Principal] addClass() - Failed with status ${res.statusCode}: ${res.data}');
        _classes.remove(entry);
      }
    } catch (e, st) {
      _classes.remove(entry);
      debugPrint('[Principal] addClass() ERROR: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> addTeacher({
    required String name,
    required String dept,
    required String phone,
  }) async {
    final entry = _MemberEntry(
        id: '', name: name, classOrDept: dept, phone: phone, address: '');
    _teachers.add(entry);
    notifyListeners();
    debugPrint('[Principal] addTeacher() - Adding: $name (Dept: $dept)');
    try {
      final res = await _principalDio().post(
        '$_kPrincipalBase/api/principal/members',
        data: {
          'type': 'teacher',
          'name': name,
          'classOrDept': dept,
          'phone': phone,
          'principalId': _kPrincipalId
        },
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        entry.id = res.data['id'].toString();
        debugPrint('[Principal] addTeacher() - Success! ID: ${entry.id}');
      } else {
        debugPrint(
            '[Principal] addTeacher() - Failed with status ${res.statusCode}: ${res.data}');
        _teachers.remove(entry);
      }
    } catch (e, st) {
      _teachers.remove(entry);
      debugPrint('[Principal] addTeacher() ERROR: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> addStudent({
    required String name,
    required String classSection,
    required String phone,
  }) async {
    final entry = _MemberEntry(
        id: '',
        name: name,
        classOrDept: classSection,
        phone: phone,
        address: '');
    _students.add(entry);
    notifyListeners();
    debugPrint(
        '[Principal] addStudent() - Adding: $name (Class: $classSection)');
    try {
      final res = await _principalDio().post(
        '$_kPrincipalBase/api/principal/members',
        data: {
          'type': 'student',
          'name': name,
          'classOrDept': classSection,
          'phone': phone,
          'principalId': _kPrincipalId
        },
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        entry.id = res.data['id'].toString();
        debugPrint('[Principal] addStudent() - Success! ID: ${entry.id}');
      } else {
        debugPrint(
            '[Principal] addStudent() - Failed with status ${res.statusCode}: ${res.data}');
        _students.remove(entry);
      }
    } catch (e, st) {
      _students.remove(entry);
      debugPrint('[Principal] addStudent() ERROR: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> addStaff({
    required String name,
    required String role,
    required String empId,
    required String phone,
  }) async {
    final entry = _MemberEntry(
        id: '', name: name, classOrDept: role, phone: phone, address: empId);
    _staff.add(entry);
    notifyListeners();
    debugPrint('[Principal] addStaff() - Adding: $name (Role: $role)');
    try {
      final res = await _principalDio().post(
        '$_kPrincipalBase/api/principal/members',
        data: {
          'type': 'staff',
          'name': name,
          'classOrDept': role,
          'phone': phone,
          'address': empId,
          'principalId': _kPrincipalId
        },
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        entry.id = res.data['id'].toString();
        debugPrint('[Principal] addStaff() - Success! ID: ${entry.id}');
      } else {
        debugPrint(
            '[Principal] addStaff() - Failed with status ${res.statusCode}: ${res.data}');
        _staff.remove(entry);
      }
    } catch (e, st) {
      _staff.remove(entry);
      debugPrint('[Principal] addStaff() ERROR: $e\n$st');
    }
    notifyListeners();
  }

  // ── Update ────────────────────────────────────────────────────────
  Future<void> updateMember(String id, String name, String classOrDept,
      String phone, String address) async {
    for (final list in [_teachers, _students, _staff]) {
      final idx = list.indexWhere((m) => m.id == id);
      if (idx != -1) {
        list[idx].name = name;
        list[idx].classOrDept = classOrDept;
        list[idx].phone = phone;
        list[idx].address = address;
        notifyListeners();
        break;
      }
    }
    try {
      await _principalDio().put(
        '$_kPrincipalBase/api/principal/members/$id',
        data: {
          'name': name,
          'classOrDept': classOrDept,
          'phone': phone,
          'address': address
        },
      );
    } catch (e) {
      debugPrint('[principal] updateMember error: $e');
    }
  }

  // ── Remove ────────────────────────────────────────────────────────
  Future<void> removeTeacher(String id) async {
    _teachers.removeWhere((m) => m.id == id);
    notifyListeners();
    try {
      await _principalDio()
          .delete('$_kPrincipalBase/api/principal/members/$id');
    } catch (e) {
      debugPrint('[principal] removeTeacher error: $e');
    }
  }

  Future<void> removeStudent(String id) async {
    _students.removeWhere((m) => m.id == id);
    notifyListeners();
    try {
      await _principalDio()
          .delete('$_kPrincipalBase/api/principal/members/$id');
    } catch (e) {
      debugPrint('[principal] removeStudent error: $e');
    }
  }

  Future<void> removeStaff(String id) async {
    _staff.removeWhere((m) => m.id == id);
    notifyListeners();
    try {
      await _principalDio()
          .delete('$_kPrincipalBase/api/principal/members/$id');
    } catch (e) {
      debugPrint('[principal] removeStaff error: $e');
    }
  }

  Future<void> removeClass(String id) async {
    _classes.removeWhere((c) => c.id == id);
    notifyListeners();
    try {
      await _principalDio()
          .delete('$_kPrincipalBase/api/principal/classes/$id');
    } catch (e) {
      debugPrint('[principal] removeClass error: $e');
    }
  }
}

class _AddClassSheet extends StatefulWidget {
  const _AddClassSheet();
  @override
  State<_AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<_AddClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _classNameCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();

  @override
  void dispose() {
    _classNameCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.secondary;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.class_, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Add Class',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 28),

              // Class / Course Name Field
              TextFormField(
                controller: _classNameCtrl,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Class / Course Name is required';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Class / Course Name',
                  hintText: 'e.g., Grade 10, Class XII',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded,
                      size: 20, color: color),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.error, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 16),

              // Section / Batch Field
              TextFormField(
                controller: _sectionCtrl,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Section / Batch (Year) is required';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Section / Batch (Year)',
                  hintText: 'e.g., Section A, Batch 2024',
                  prefixIcon:
                      Icon(Icons.label_outline_rounded, size: 20, color: color),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.error, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final className = _classNameCtrl.text.trim();
                      final section = _sectionCtrl.text.trim();
                      final name = '$className – $section';

                      SchoolDataStore.instance.addClass(name);
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Class saved successfully'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Class'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTeacherSheet extends StatelessWidget {
  const _AddTeacherSheet();
  @override
  Widget build(BuildContext context) => _SchoolFormSheet(
        title: 'Add Teacher',
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.roleTeacher,
        fields: const [
          _FieldDef('Full Name', Icons.person_outlined),
          _FieldDef('Subject', Icons.menu_book_outlined),
          _FieldDef('Phone Number', Icons.phone_outlined),
        ],
        onSave: (values) => SchoolDataStore.instance.addTeacher(
          name: values[0],
          dept: values[1],
          phone: values[2],
        ),
      );
}

class _AddStudentSheet extends StatelessWidget {
  final String? prefilledClass;
  const _AddStudentSheet({this.prefilledClass});
  @override
  Widget build(BuildContext context) => _SchoolFormSheet(
        title: 'Add Student',
        icon: Icons.school_rounded,
        color: AppColors.primary,
        fields: const [
          _FieldDef('Student Name', Icons.person_outlined),
          _FieldDef('Admission No.', Icons.numbers_rounded),
          _FieldDef('Class & Section', Icons.class_),
          _FieldDef("Father's Name", Icons.family_restroom_outlined),
          _FieldDef('Phone Number', Icons.phone_outlined),
        ],
        initialValues:
            prefilledClass != null ? ['', '', prefilledClass!, '', ''] : null,
        onSave: (values) => SchoolDataStore.instance.addStudent(
          name: values[0],
          classSection: values[2],
          phone: values[4],
        ),
      );
}

class _AddStaffSheet extends StatelessWidget {
  const _AddStaffSheet();
  @override
  Widget build(BuildContext context) => _SchoolFormSheet(
        title: 'Add Staff',
        icon: Icons.badge_rounded,
        color: AppColors.accent,
        fields: const [
          _FieldDef('Full Name', Icons.person_outlined),
          _FieldDef('Staff Role', Icons.work_outline_rounded),
          _FieldDef('Employee ID', Icons.badge_outlined),
          _FieldDef('Phone Number', Icons.phone_outlined),
        ],
        onSave: (values) => SchoolDataStore.instance.addStaff(
          name: values[0],
          role: values[1],
          empId: values[2],
          phone: values[3],
        ),
      );
}

class _FieldDef {
  final String label;
  final IconData icon;
  const _FieldDef(this.label, this.icon);
}

class _SchoolFormSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FieldDef> fields;
  final void Function(List<String> values) onSave;
  final List<String>? initialValues;
  const _SchoolFormSheet({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
    required this.onSave,
    this.initialValues,
  });

  @override
  State<_SchoolFormSheet> createState() => _SchoolFormSheetState();
}

class _SchoolFormSheetState extends State<_SchoolFormSheet> {
  late final List<TextEditingController> _ctrls;

  bool get _canSave => _ctrls.isNotEmpty && _ctrls[0].text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      widget.fields.length,
      (i) => TextEditingController(
        text: (widget.initialValues != null && i < widget.initialValues!.length)
            ? widget.initialValues![i]
            : '',
      ),
    );
    for (final c in _ctrls) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(widget.title,
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 24),
            ...widget.fields.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _ctrls[e.key],
                      decoration: InputDecoration(
                        labelText: e.value.label,
                        prefixIcon: Icon(e.value.icon, size: 20, color: color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: color, width: 2),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _canSave
                    ? () {
                        widget
                            .onSave(_ctrls.map((c) => c.text.trim()).toList());
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${widget.title} saved successfully'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.check_rounded),
                label: Text('Save ${widget.title}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: color.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINCIPAL DATA SCREEN  (Data tab — school hierarchy)
// ═══════════════════════════════════════════════════════════════════

class PrincipalDataScreen extends StatefulWidget {
  const PrincipalDataScreen({super.key});

  @override
  State<PrincipalDataScreen> createState() => _PrincipalDataScreenState();
}

class _PrincipalDataScreenState extends State<PrincipalDataScreen> {
  @override
  void initState() {
    super.initState();
    // Always reload so newly imported Excel data appears immediately
    SchoolDataStore.instance.reload();
  }

  static const _teal = AppColors.secondary;

  static const _sectionMeta = [
    (Icons.class_, 'Classes', 'classes', AppColors.secondary),
    (Icons.person_rounded, 'Teachers', 'teachers', AppColors.roleTeacher),
    (Icons.school_rounded, 'Students', 'students', AppColors.primary),
    (Icons.badge_rounded, 'Staff', 'staff', AppColors.secondary),
  ];

  String _liveCount(String title) {
    final store = SchoolDataStore.instance;
    if (store.isLoading) return '…';
    switch (title) {
      case 'Classes':
        return '${store.classCount}';
      case 'Teachers':
        return '${store.teacherCount}';
      case 'Students':
        return '${store.studentCount}';
      case 'Staff':
        return '${store.staffCount}';
      default:
        return '–';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolDataStore.instance,
      builder: (context, _) {
        final liveSections = _sectionMeta
            .map((m) => _SectionDef(
                  icon: m.$1,
                  title: m.$2,
                  count: _liveCount(m.$2),
                  unit: m.$3,
                  subtitle: '',
                  color: m.$4,
                ))
            .toList();

        final store = SchoolDataStore.instance;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => SchoolDataStore.instance.reload(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  title: const Text('School Data'),
                  actions: [
                    if (store.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh',
                        onPressed: () => SchoolDataStore.instance.reload(),
                      ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── School Header Card ──────────────────────────
                      _SchoolHeaderCard(teal: _teal)
                          .animate()
                          .fadeIn(duration: 300.ms),
                      const SizedBox(height: 24),

                      // ── Section label ────────────────────────────────
                      Row(children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _teal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Data Sections',
                            style: AppTypography.titleSmall
                                .copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 14),

                      // ── 4 Section Cards ──────────────────────────────
                      ...liveSections.asMap().entries.map((e) {
                        final s = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SchoolSectionCard(
                            def: s,
                            onTap: () {
                              if (s.title == 'Classes') {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const _ClassListScreen(),
                                ));
                              } else {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => _SchoolSectionScreen(
                                    title: s.title,
                                    icon: s.icon,
                                    color: s.color,
                                    totalCountLabel: '${s.count} ${s.unit}',
                                  ),
                                ));
                              }
                            },
                          )
                              .animate(
                                  delay: Duration(milliseconds: 80 * e.key))
                              .fadeIn(duration: 250.ms)
                              .slideX(begin: 0.04, end: 0),
                        );
                      }),
                    ]),
                  ),
                ),
              ],
            ),
          ), // RefreshIndicator
        );
      },
    );
  }
}

class _SectionDef {
  final IconData icon;
  final String title;
  final String count;
  final String unit;
  final String subtitle;
  final Color color;
  const _SectionDef({
    required this.icon,
    required this.title,
    required this.count,
    required this.unit,
    required this.subtitle,
    required this.color,
  });
}

// ── School Header Card ───────────────────────────────────────────────

class _SchoolHeaderCard extends StatelessWidget {
  final Color teal;
  const _SchoolHeaderCard({this.teal = AppColors.secondary});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolDataStore.instance,
      builder: (context, _) {
        final store = SchoolDataStore.instance;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [teal, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: teal.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.domain_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('–',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Text('–',
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.white.withOpacity(0.75))),
                    const SizedBox(height: 12),
                    Row(children: [
                      _MiniStat('${store.studentCount}', 'Students'),
                      const SizedBox(width: 16),
                      _MiniStat('${store.teacherCount}', 'Teachers'),
                      const SizedBox(width: 16),
                      _MiniStat('${store.classCount}', 'Classes'),
                    ]),
                  ]),
            ),
          ]),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: AppTypography.labelLarge
              .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      Text(label,
          style: AppTypography.caption
              .copyWith(color: Colors.white.withOpacity(0.7))),
    ]);
  }
}

// ── Section Card ─────────────────────────────────────────────────────

class _SchoolSectionCard extends StatelessWidget {
  final _SectionDef def;
  final VoidCallback onTap;
  const _SchoolSectionCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: def.color.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: def.color.withOpacity(isDark ? 0.08 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: def.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(def.icon, color: def.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.title,
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(def.subtitle,
                        style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: def.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(def.count,
                  style: AppTypography.titleSmall
                      .copyWith(color: def.color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: def.color.withOpacity(0.6)),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CLASS PROMOTION HELPER  (principal)
// ═══════════════════════════════════════════════════════════════════

/// Shows a confirmation dialog and, on confirm, POSTs to the backend
/// promote-class endpoint.  Refreshes [SchoolDataStore] on success.
Future<void> _showPromoteDialog(BuildContext context, String className) async {
  final sm = ScaffoldMessenger.of(context);

  // Validate: name must begin with a digit
  final match = RegExp(r'^(\d+)(.*)$').firstMatch(className.trim());
  if (match == null) {
    sm.showSnackBar(SnackBar(
      content: Text(
          '"$className" cannot be auto-promoted — name must start with a number (e.g. "1 - A")'),
    ));
    return;
  }

  final nextNum = int.parse(match.group(1)!) + 1;
  final nextName = '$nextNum${match.group(2)!}';

  if (nextNum > 12) {
    sm.showSnackBar(SnackBar(
      content:
          Text('"$className" is already at class 12 — cannot promote further.'),
    ));
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.trending_up_rounded, color: AppColors.secondary),
        const SizedBox(width: 8),
        const Text('Promote Class'),
      ]),
      content: Text(
        'Move all students from\n'
        '"$className"  →  "$nextName"\n\n'
        'If "$nextName" does not exist it will be created automatically.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.trending_up_rounded, size: 18),
          label: const Text('Promote'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Show progress snackbar
  sm.showSnackBar(SnackBar(
    content: Row(children: [
      const SizedBox(
          width: 18,
          height: 18,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      const SizedBox(width: 12),
      Text('Promoting "$className" → "$nextName"…'),
    ]),
    duration: const Duration(seconds: 20),
  ));

  try {
    final res = await _principalDio().post(
      ApiConfig.principalPromoteClass,
      data: {'className': className, 'principalId': _kPrincipalId},
    );
    sm.hideCurrentSnackBar();

    if (res.statusCode == 200) {
      final count =
          (res.data as Map?)?.cast<String, dynamic>()['studentsPromoted'] ?? 0;
      sm.showSnackBar(SnackBar(
        content: Text('✓ Promoted to "$nextName" — $count student(s) moved.'),
        backgroundColor: AppColors.success,
      ));
      SchoolDataStore.instance.reload();
    } else {
      final msg = ((res.data as Map?)?.cast<String, dynamic>()['error']) ??
          'Failed to promote class';
      sm.showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (e) {
    sm.hideCurrentSnackBar();
    sm.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

// ═══════════════════════════════════════════════════════════════════
// CLASS LIST SCREEN
// ═══════════════════════════════════════════════════════════════════

class _ClassListScreen extends StatelessWidget {
  const _ClassListScreen();

  _ClassInfo _toClassInfo(_SchoolClass sc) {
    final studentCount = SchoolDataStore.instance.students
        .where((s) => s.classOrDept == sc.name)
        .length;
    return _ClassInfo(
      name: sc.name,
      total: studentCount,
      ready: 0,
      color: AppColors.secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolDataStore.instance,
      builder: (context, _) {
        final classes =
            SchoolDataStore.instance.classes.map(_toClassInfo).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Classes'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Class'),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              builder: (_) => const _AddClassSheet(),
            ),
          ),
          body: classes.isEmpty
              ? const Center(child: Text('No classes added yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final c = classes[i];
                    final progress = c.total == 0 ? 0.0 : c.ready / c.total;
                    return InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _ClassDetailScreen(classInfo: c),
                      )),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: c.color.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: c.color.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(children: [
                          Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  Icon(Icons.class_, color: c.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: AppTypography.labelLarge
                                        .copyWith(fontWeight: FontWeight.w700)),
                                Text('Total: ${c.total} students',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5))),
                              ],
                            )),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: AppTypography.titleSmall.copyWith(
                                        color: c.color,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text('Ready',
                                      style: AppTypography.caption.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.45))),
                                ]),
                            const SizedBox(width: 4),
                            // ── Promote button ──────────────────────
                            Tooltip(
                              message: 'Promote to next class',
                              child: InkWell(
                                onTap: () =>
                                    _showPromoteDialog(context, c.name),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: c.color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.trending_up_rounded,
                                    size: 20,
                                    color: c.color,
                                  ),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              color: c.color,
                              backgroundColor: c.color.withOpacity(0.1),
                              minHeight: 6,
                            ),
                          ),
                        ]),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 50 * i))
                        .fadeIn(duration: 200.ms);
                  },
                ),
        );
      },
    );
  }
}

class _ClassInfo {
  final String name;
  final int total;
  final int ready;
  final Color color;
  const _ClassInfo({
    required this.name,
    required this.total,
    required this.ready,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════════
// CLASS DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════

class _ClassDetailScreen extends StatelessWidget {
  final _ClassInfo classInfo;
  const _ClassDetailScreen({required this.classInfo});

  static final _statusCats = [
    ('All Students', Icons.people_rounded, AppColors.primary),
    ('Without Photo', Icons.no_photography_rounded, AppColors.warning),
    ('Unchecked Data', Icons.pending_outlined, AppColors.accent),
    ('Ready to Print', Icons.print_rounded, AppColors.success),
    ('Printing', Icons.local_print_shop_rounded, AppColors.secondary),
    ('Delivered', Icons.check_circle_rounded, AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(classInfo.name),
        backgroundColor: classInfo.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [classInfo.color, classInfo.color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Expanded(child: _BannerStat('${classInfo.total}', 'Total')),
              Expanded(child: _BannerStat('${classInfo.ready}', 'Ready')),
              Expanded(
                  child: _BannerStat(
                      '${classInfo.total - classInfo.ready}', 'Pending')),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Filter by Status',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ..._statusCats.asMap().entries.map((e) {
            final (label, icon, color) = e.value;
            final count = label == 'All Students'
                ? classInfo.total
                : (classInfo.total * [1, 0.08, 0.12, 0.74, 0.04, 0.74][e.key])
                    .round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FilteredMemberListScreen(
                    category: label,
                    section: classInfo.name,
                    count: count,
                    icon: icon,
                    color: color,
                  ),
                )),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: color.withOpacity(0.18), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(label, style: AppTypography.labelLarge)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count',
                          style:
                              AppTypography.labelSmall.copyWith(color: color)),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        color: color.withOpacity(0.5), size: 20),
                  ]),
                ),
              ).animate(delay: Duration(milliseconds: 50 * e.key)).fadeIn(),
            );
          }),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String value;
  final String label;
  const _BannerStat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: AppTypography.titleMedium
              .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      Text(label,
          style: AppTypography.caption
              .copyWith(color: Colors.white.withOpacity(0.75))),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCHOOL SECTION SCREEN (Teachers / Students / Staff)
// ═══════════════════════════════════════════════════════════════════

class _SchoolSectionScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String totalCountLabel;
  const _SchoolSectionScreen({
    required this.title,
    required this.icon,
    required this.color,
    required this.totalCountLabel,
  });

  static final _cats = [
    ('All', Icons.people_rounded),
    ('Without Photo', Icons.no_photography_rounded),
    ('Unchecked Data', Icons.pending_outlined),
    ('Ready to Print', Icons.print_rounded),
    ('Printing', Icons.local_print_shop_rounded),
    ('Delivered', Icons.check_circle_rounded),
  ];

  static const _catColors = [
    AppColors.primary,
    AppColors.warning,
    AppColors.accent,
    AppColors.success,
    AppColors.secondary,
    AppColors.success,
  ];

  int _totalForTitle() {
    final store = SchoolDataStore.instance;
    switch (title) {
      case 'Teachers':
        return store.teacherCount;
      case 'Students':
        return store.studentCount;
      case 'Staff':
        return store.staffCount;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolDataStore.instance,
      builder: (context, _) {
        final liveTotal = _totalForTitle();
        final liveCounts = [liveTotal, 0, 0, 0, 0, 0];
        final liveTotalLabel = '$liveTotal ${title.toLowerCase()}';
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header summary
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w700, color: color)),
                        Text(liveTotalLabel, style: AppTypography.bodySmall),
                      ])),
                ]),
              ).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: 20),
              Text('Filter by Status',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ..._cats.asMap().entries.map((e) {
                final (label, catIcon) = e.value;
                final catColor = _catColors[e.key];
                final count = liveCounts[e.key];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _FilteredMemberListScreen(
                        category: '$title – $label',
                        section: title,
                        count: count,
                        icon: catIcon,
                        color: catColor,
                      ),
                    )),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: catColor.withOpacity(0.18), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: catColor.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(catIcon, color: catColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child:
                                Text(label, style: AppTypography.labelLarge)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$count',
                              style: AppTypography.labelSmall
                                  .copyWith(color: catColor)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: catColor.withOpacity(0.5), size: 20),
                      ]),
                    ),
                  ).animate(delay: Duration(milliseconds: 50 * e.key)).fadeIn(),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Member Entry Model ──────────────────────────────────────────────────────

class _MemberEntry {
  String id;
  String name;
  String classOrDept;
  String phone;
  String address;
  String profileImage;
  bool isBlocked = false;

  _MemberEntry({
    required this.id,
    required this.name,
    required this.classOrDept,
    required this.phone,
    required this.address,
    this.profileImage = '',
  });
}

// ═══════════════════════════════════════════════════════════════════
// FILTERED MEMBER LIST SCREEN
// ═══════════════════════════════════════════════════════════════════

class _FilteredMemberListScreen extends StatefulWidget {
  final String category;
  final String section;
  final int count;
  final IconData icon;
  final Color color;
  const _FilteredMemberListScreen({
    required this.category,
    required this.section,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  State<_FilteredMemberListScreen> createState() =>
      _FilteredMemberListScreenState();
}

class _FilteredMemberListScreenState extends State<_FilteredMemberListScreen> {
  late List<_MemberEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = _loadFromStore();
    SchoolDataStore.instance.addListener(_onStoreChanged);
    SchoolDataStore.instance.reload();
  }

  void _onStoreChanged() {
    if (mounted) setState(() => _items = _loadFromStore());
  }

  @override
  void dispose() {
    SchoolDataStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  List<_MemberEntry> _loadFromStore() {
    final store = SchoolDataStore.instance;
    final sec = widget.section.toLowerCase();
    if (sec == 'teachers') return store.teachers.toList();
    if (sec == 'students') return store.students.toList();
    if (sec == 'staff') return store.staff.toList();
    // Class-specific: show students assigned to that class
    return store.students
        .where((s) => s.classOrDept == widget.section)
        .toList();
  }

  void _removeFromStore(String id) {
    final store = SchoolDataStore.instance;
    final sec = widget.section.toLowerCase();
    if (sec == 'teachers') {
      store.removeTeacher(id);
    } else if (sec == 'students') {
      store.removeStudent(id);
    } else if (sec == 'staff') {
      store.removeStaff(id);
    } else {
      store.removeStudent(id); // class-specific
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────
  void _editItem(int index) {
    final item = _items[index];
    final isTeacher = widget.section.toLowerCase().contains('teacher');
    final isStaff = widget.section.toLowerCase().contains('staff');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditMemberSheet(
        item: item,
        color: widget.color,
        isTeacher: isTeacher,
        isStaff: isStaff,
        onSaved: (name, classOrDept, phone, address) {
          setState(() {
            _items[index].name = name;
            _items[index].classOrDept = classOrDept;
            _items[index].phone = phone;
            _items[index].address = address;
          });
          SchoolDataStore.instance
              .updateMember(item.id, name, classOrDept, phone, address);
        },
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────
  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          const Text('Confirm Delete'),
        ]),
        content: Text(
          'Are you sure you want to delete "${_items[index].name}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              final item = _items[index];
              setState(() => _items.removeAt(index));
              _removeFromStore(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Record deleted'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Block / Unblock ───────────────────────────────────────────────
  void _toggleBlock(int index) {
    final item = _items[index];
    final willBlock = !item.isBlocked;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            willBlock
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            color: willBlock ? AppColors.warning : AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(willBlock ? 'Block User' : 'Unblock User'),
        ]),
        content: Text(
          willBlock
              ? '"${item.name}" will be blocked and cannot log in.'
              : '"${item.name}" will be unblocked and can log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  willBlock ? AppColors.warning : AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              setState(() => _items[index].isBlocked = willBlock);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    willBlock
                        ? '${item.name} has been blocked'
                        : '${item.name} has been unblocked',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(willBlock ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
  }

  // ── Assign Class (students only) ──────────────────────────────────
  Future<void> _assignClass(int index) async {
    final item = _items[index];
    const predefinedSections = ['A', 'B', 'C', 'D', 'E'];

    // ── Fetch real classes from DB ───────────────────────────────────
    List<Map<String, dynamic>> dbClasses = [];
    bool loadError = false;
    try {
      final pid = await _ensurePrincipalId();
      final resp = await Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      )).get('/api/principal/classes', queryParameters: {'principalId': pid});
      final raw = resp.data;
      if (raw is List) {
        dbClasses =
            raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      loadError = true;
    }

    if (!mounted) return;

    // Pre-fill current selection
    String selectedClassId = ''; // DB class _id
    String selectedClassName = ''; // display name
    String selectedSection = '';

    // Try to match existing classOrDept value to a DB class
    final existing = item.classOrDept.trim();
    if (existing.isNotEmpty) {
      final existingName =
          existing.contains('-') ? existing.split('-').first.trim() : existing;
      selectedSection =
          existing.contains('-') ? existing.split('-').last.trim() : '';
      final match = dbClasses.firstWhere(
        (c) =>
            (c['name'] ?? '').toString().toLowerCase() ==
            existingName.toLowerCase(),
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        selectedClassId = (match['id'] ?? match['_id'] ?? '').toString();
        selectedClassName = (match['name'] ?? '').toString();
      } else {
        selectedClassName = existingName;
      }
    }

    // ── Show dialog ──────────────────────────────────────────────────
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.class_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Assign Class — ${item.name}',
                    style: AppTypography.labelLarge)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Class chips (from DB) ──────────────────────────
                Text('Class',
                    style: AppTypography.caption
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (loadError)
                  const Text('Could not load classes.',
                      style: TextStyle(color: Colors.red, fontSize: 13))
                else if (dbClasses.isEmpty)
                  const Text('No classes added yet.',
                      style: TextStyle(fontSize: 13))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dbClasses.map((cls) {
                      final id = (cls['id'] ?? cls['_id'] ?? '').toString();
                      final name = (cls['name'] ?? '').toString();
                      final sel = selectedClassId == id;
                      return ChoiceChip(
                        label: Text(
                          name,
                          style: TextStyle(
                            color: sel ? AppColors.primary : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: sel,
                        selectedColor: AppColors.primary.withOpacity(0.18),
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide(
                          color: sel ? AppColors.primary : Colors.grey.shade300,
                        ),
                        onSelected: (_) => setDlgState(() {
                          selectedClassId = id;
                          selectedClassName = name;
                        }),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 16),

                // ── Section chips ──────────────────────────────────
                Text('Section',
                    style: AppTypography.caption
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: predefinedSections.map((sec) {
                    final sel = selectedSection == sec;
                    return ChoiceChip(
                      label: Text(
                        sec,
                        style: TextStyle(
                          color: sel ? AppColors.primary : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: sel,
                      selectedColor: AppColors.primary.withOpacity(0.18),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(
                        color: sel ? AppColors.primary : Colors.grey.shade300,
                      ),
                      onSelected: (_) => setDlgState(() {
                        selectedSection = sel ? '' : sec;
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Assign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: selectedClassName.isEmpty
                  ? null
                  : () async {
                      Navigator.of(dialogCtx).pop();
                      final displayClass = selectedSection.isEmpty
                          ? selectedClassName
                          : '$selectedClassName-$selectedSection';
                      try {
                        final token =
                            await AuthService.instance.getStoredToken();
                        await Dio(BaseOptions(
                          baseUrl: ApiConfig.baseUrl,
                          connectTimeout: const Duration(seconds: 10),
                          receiveTimeout: const Duration(seconds: 10),
                        )).put(
                          '/api/students/${item.id}/assign-class',
                          data: {
                            'className': selectedClassName,
                            'section': selectedSection,
                          },
                          options: Options(headers: {
                            if (token != null) 'Authorization': 'Bearer $token'
                          }),
                        );
                        if (!mounted) return;
                        setState(() {
                          _items[index].classOrDept = displayClass;
                        });
                        SchoolDataStore.instance.updateMember(
                          item.id,
                          item.name,
                          displayClass,
                          item.phone,
                          item.address,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${item.name} assigned to $displayClass'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to assign class: $e'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────────
  void _showImport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ImportSheet(
        section: widget.section,
        color: widget.color,
      ),
    );
  }

  // ── Add ───────────────────────────────────────────────────────────
  void _showAddSheet() {
    final sec = widget.section.toLowerCase();
    Widget sheet;
    if (sec == 'teachers') {
      sheet = const _AddTeacherSheet();
    } else if (sec == 'staff') {
      sheet = const _AddStaffSheet();
    } else if (sec == 'students') {
      sheet = const _AddStudentSheet();
    } else {
      // Class-specific view — prefill the class name
      sheet = _AddStudentSheet(prefilledClass: widget.section);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sec = widget.section.toLowerCase();
    final isClass = sec != 'teachers' && sec != 'students' && sec != 'staff';
    final fabLabel = sec == 'teachers'
        ? 'Add Teacher'
        : sec == 'staff'
            ? 'Add Staff'
            : 'Add Student';
    final fabIcon = sec == 'teachers'
        ? Icons.person_add_alt_1_rounded
        : sec == 'staff'
            ? Icons.badge_rounded
            : Icons.school_rounded;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showImport,
              icon: const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Import',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isClass ? AppColors.primary : widget.color,
        foregroundColor: Colors.white,
        icon: Icon(fabIcon),
        label: Text(fabLabel),
        onPressed: _showAddSheet,
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 72, color: widget.color.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text('All caught up!',
                        style: AppTypography.titleSmall
                            .copyWith(color: widget.color)),
                    Text('No records in this category',
                        style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                  ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = _items[i];
                final day = (i % 28) + 1;
                final month = ['Jan', 'Feb', 'Mar', 'Apr'][(i ~/ 7) % 4];
                final formDate = '$day $month 2025';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.isBlocked
                        ? Theme.of(context).colorScheme.surface.withOpacity(0.7)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.isBlocked
                          ? Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.3)
                          : widget.color.withOpacity(0.15),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    // Avatar — profile photo if available, else initial
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.isBlocked
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.1)
                            : widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: item.profileImage.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                ApiConfig.resolveImageUrl(item.profileImage),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    item.name.isNotEmpty ? item.name[0] : '?',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: item.isBlocked
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.4)
                                          : widget.color,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                item.name.isNotEmpty ? item.name[0] : '?',
                                style: AppTypography.labelLarge.copyWith(
                                  color: item.isBlocked
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.4)
                                      : widget.color,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    // Name + class/dept + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: AppTypography.labelMedium.copyWith(
                              color: item.isBlocked
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.45)
                                  : null,
                            ),
                          ),
                          Text(
                            item.classOrDept,
                            style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5)),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: widget.color.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formDate,
                              style: AppTypography.caption.copyWith(
                                color: widget.color.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    // Badges + overflow menu
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Blocked badge OR status badge
                        if (item.isBlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.3)),
                            ),
                            child: Text('Blocked',
                                style: AppTypography.caption.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                    fontWeight: FontWeight.w600)),
                          )
                        else
                          RoleBadge(
                            label: widget.category.contains('Delivered')
                                ? 'Done'
                                : widget.category.contains('Printing')
                                    ? 'Printing'
                                    : widget.category.contains('Ready')
                                        ? 'Ready'
                                        : 'Pending',
                            color: widget.color,
                          ),
                        // Assign button (teachers only – shown in All view)
                        if (widget.section.toLowerCase().contains('teacher') &&
                            widget.category.contains('– All')) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28)),
                              ),
                              builder: (_) =>
                                  const _AssignClassToTeacherSheet(),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.roleTeacher.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.roleTeacher.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.assignment_ind_rounded,
                                        size: 12, color: AppColors.roleTeacher),
                                    const SizedBox(width: 4),
                                    Text('Assign',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.roleTeacher,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ]),
                            ),
                          ),
                        ],
                        // Assign Class button (students only – shown in All view)
                        if (widget.section.toLowerCase() == 'students' &&
                            widget.category.contains('– All')) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _assignClass(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.class_rounded,
                                        size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.classOrDept.trim().isEmpty
                                          ? 'Assign'
                                          : item.classOrDept,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        ],
                        // Assign Class button (students only – shown in All view)
                        if (widget.section.toLowerCase() == 'students' &&
                            widget.category.contains('– All')) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _assignClass(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.class_rounded,
                                        size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.classOrDept.trim().isEmpty
                                          ? 'Unassigned'
                                          : item.classOrDept,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        ],
                        // Assign Role button (staff only – shown in All view)
                        if (widget.section.toLowerCase().contains('staff') &&
                            widget.category.contains('– All')) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28)),
                              ),
                              builder: (_) => _AssignStaffRoleSheet(
                                staffName: item.name,
                                currentRole: item.classOrDept,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.accent.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.manage_accounts_rounded,
                                        size: 12, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text('Assign Role',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ]),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        // 3-dot overflow menu
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _editItem(i);
                            if (v == 'delete') _deleteItem(i);
                            if (v == 'block') _toggleBlock(i);
                            if (v == 'assign_class') _assignClass(i);
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.more_vert_rounded,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 10),
                                Text('Edit'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.error),
                                SizedBox(width: 10),
                                Text('Delete',
                                    style: TextStyle(color: AppColors.error)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Row(children: [
                                Icon(
                                  item.isBlocked
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.block_rounded,
                                  size: 18,
                                  color: item.isBlocked
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  item.isBlocked ? 'Unblock' : 'Block',
                                  style: TextStyle(
                                      color: item.isBlocked
                                          ? AppColors.success
                                          : AppColors.warning),
                                ),
                              ]),
                            ),
                            if (widget.section.toLowerCase() == 'students')
                              const PopupMenuItem(
                                value: 'assign_class',
                                child: Row(children: [
                                  Icon(Icons.class_rounded,
                                      size: 18, color: AppColors.primary),
                                  SizedBox(width: 10),
                                  Text('Assign Class',
                                      style:
                                          TextStyle(color: AppColors.primary)),
                                ]),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ]),
                ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn();
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EDIT MEMBER SHEET
// ═══════════════════════════════════════════════════════════════════

class _EditMemberSheet extends StatefulWidget {
  final _MemberEntry item;
  final Color color;
  final bool isTeacher;
  final bool isStaff;
  final void Function(
      String name, String classOrDept, String phone, String address) onSaved;

  const _EditMemberSheet({
    required this.item,
    required this.color,
    required this.isTeacher,
    required this.isStaff,
    required this.onSaved,
  });

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  static const _staffRoles = [
    'Coordinator',
    'Lab In-charge',
    'Librarian',
    'Admin',
    'Security',
    'Canteen'
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _classCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  String? _selectedStaffRole;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _classCtrl = TextEditingController(text: widget.item.classOrDept);
    _phoneCtrl = TextEditingController(text: widget.item.phone);
    _addressCtrl = TextEditingController(text: widget.item.address);
    // Pre-select staff role if classOrDept matches a known role
    if (widget.isStaff) {
      _selectedStaffRole = _staffRoles.contains(widget.item.classOrDept)
          ? widget.item.classOrDept
          : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      [TextInputType? keyboard]) {
    final color = widget.color;
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final deptLabel = widget.isTeacher
        ? 'Subject / Class'
        : widget.isStaff
            ? 'Department'
            : 'Class & Section';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.edit_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit – ${widget.item.name}',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _field(_nameCtrl, 'Full Name', Icons.person_outlined),
            const SizedBox(height: 16),
            // Staff role chip-picker replaces the free-text dept field
            if (widget.isStaff) ...[
              Text('Staff Role',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _staffRoles.map((r) {
                  final sel = _selectedStaffRole == r;
                  final onSurface = Theme.of(context).colorScheme.onSurface;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStaffRole = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            sel ? color.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? color : onSurface.withOpacity(0.25),
                          width: sel ? 1.6 : 1.2,
                        ),
                      ),
                      child: Text(
                        r,
                        style: AppTypography.labelSmall.copyWith(
                          color: sel ? color : onSurface.withOpacity(0.75),
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ] else ...[
              _field(_classCtrl, deptLabel, Icons.class_),
              const SizedBox(height: 16),
            ],
            _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                TextInputType.phone),
            const SizedBox(height: 16),
            _field(_addressCtrl, 'Address', Icons.location_on_outlined),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onSaved(
                    _nameCtrl.text.trim().isEmpty
                        ? widget.item.name
                        : _nameCtrl.text.trim(),
                    // For staff use the chip-selected role; fallback to text field
                    widget.isStaff
                        ? (_selectedStaffRole ?? widget.item.classOrDept)
                        : (_classCtrl.text.trim().isEmpty
                            ? widget.item.classOrDept
                            : _classCtrl.text.trim()),
                    _phoneCtrl.text.trim().isEmpty
                        ? widget.item.phone
                        : _phoneCtrl.text.trim(),
                    _addressCtrl.text.trim().isEmpty
                        ? widget.item.address
                        : _addressCtrl.text.trim(),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Record updated successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// IMPORT SHEET (Excel / CSV)
// ═══════════════════════════════════════════════════════════════════

class _ImportSheet extends StatefulWidget {
  final String section;
  final Color color;
  const _ImportSheet({required this.section, required this.color});

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  String? _fileName;
  bool _loading = false;

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _fileName = result.files.first.name);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.upload_file_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Import ${widget.section}',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('via Excel / CSV',
                    style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5))),
              ]),
            ]),
            const SizedBox(height: 24),
            // Expected columns info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected Columns',
                      style: AppTypography.labelMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...[
                    ('A', 'Name', 'e.g. Rahul Sharma'),
                    ('B', 'Class / Dept', 'e.g. Class 9-A or Science'),
                    ('C', 'Phone', 'e.g. +91 9876543210'),
                    ('D', 'Role', 'e.g. Student / Teacher / Staff'),
                  ].map(
                    (col) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(col.$1,
                                style: AppTypography.labelSmall
                                    .copyWith(color: color)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${col.$2}: ',
                            style: AppTypography.labelSmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Text(col.$3,
                              style: AppTypography.bodySmall.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.55))),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Selected-file indicator
            if (_fileName != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_fileName!,
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.success)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            // File picker button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickFile,
                icon: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      )
                    : Icon(Icons.folder_open_rounded, color: color),
                label: Text(
                  _loading
                      ? 'Opening picker…'
                      : _fileName == null
                          ? 'Choose .xlsx or .csv file'
                          : 'Choose different file',
                  style: TextStyle(color: color),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Import button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _fileName == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${widget.section} imported from $_fileName'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Import Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: color.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// (legacy data screen code removed — replaced by new school-hierarchy implementation above)

// -------------------------------------------------------------------
// ATTENDANCE MODULE  (Principal only)
// -------------------------------------------------------------------

// -- Top-level attendance screen � class list ---------------------

class PrincipalAttendanceScreen extends StatelessWidget {
  const PrincipalAttendanceScreen({super.key});

  static const _green = AppColors.success;
  static const _classNames = <String>[];
  static const _totals = <int>[];
  static const _present = <int>[];

  static String _wd(int d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  static String _mn(int m) => const [
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
        'Dec'
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${_wd(now.weekday)}, ${now.day} ${_mn(now.month)} ${now.year}';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            title: const Text('Attendance'),
          ),
          SliverToBoxAdapter(
            child: _ASchoolHeader(green: _green, dateLabel: dateLabel)
                .animate()
                .fadeIn(duration: 300.ms),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = _present[i];
                  final t = _totals[i];
                  final pct = (p / t * 100).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ClassAttendanceScreen(
                            className: _classNames[i],
                            total: t,
                            presentToday: p,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: _green.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: AppTypography.titleMedium.copyWith(
                                      color: _green,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_classNames[i],
                                    style: AppTypography.labelLarge
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: p / t,
                                    color: _green,
                                    backgroundColor: _green.withOpacity(0.1),
                                    minHeight: 5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('$p / $t present',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$pct%',
                                style: AppTypography.labelSmall.copyWith(
                                    color: _green,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              color: _green.withOpacity(0.5)),
                        ]),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 50 * i))
                        .fadeIn(duration: 200.ms)
                        .slideX(begin: 0.04, end: 0),
                  );
                },
                childCount: _classNames.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ASchoolHeader extends StatelessWidget {
  final Color green;
  final String dateLabel;
  const _ASchoolHeader({required this.green, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [green, const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              const Icon(Icons.domain_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('–',
                style: AppTypography.titleSmall.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(dateLabel,
                style: AppTypography.bodySmall
                    .copyWith(color: Colors.white.withOpacity(0.75))),
            const SizedBox(height: 10),
            Row(children: [
              _AChip('–', 'Total', Colors.white),
              const SizedBox(width: 16),
              _AChip('–', 'Present', Colors.white),
              const SizedBox(width: 16),
              _AChip('–', 'Absent', Colors.white.withOpacity(0.75)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _AChip extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _AChip(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val,
            style: AppTypography.labelLarge
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        Text(lbl,
            style: AppTypography.caption.copyWith(color: col.withOpacity(0.8))),
      ]);
}

// -------------------------------------------------------------------
// CLASS ATTENDANCE SCREEN  (3 large action cards)
// -------------------------------------------------------------------

class _ClassAttendanceScreen extends StatelessWidget {
  final String className;
  final int total;
  final int presentToday;
  const _ClassAttendanceScreen({
    required this.className,
    required this.total,
    required this.presentToday,
  });

  static const _green = AppColors.success;

  @override
  Widget build(BuildContext context) {
    final absent = total - presentToday;
    final pct = (presentToday / total * 100).toInt();

    final actions = [
      (
        Icons.qr_code_scanner_rounded,
        'Scanner Attendance',
        'Scan QR or Barcode on student ID card',
        AppColors.primary,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ScannerAttendanceScreen(className: className),
            )),
      ),
      (
        Icons.checklist_rounded,
        'Manual Attendance',
        'Mark attendance from the student list',
        _green,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  _ManualAttendanceScreen(className: className, total: total),
            )),
      ),
      (
        Icons.history_rounded,
        'View Attendance',
        'Browse historical attendance records',
        AppColors.accent,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ViewAttendanceScreen(className: className),
            )),
      ),
      (
        Icons.bar_chart_rounded,
        'Attendance Report',
        'Generate individual or class attendance report with PDF export',
        AppColors.primary,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TAttendanceReportScreen(
                className: className,
                total: total,
              ),
            )),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _green.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AStat('$total', 'Total', Colors.white),
                _AStat('$presentToday', 'Present', Colors.white),
                _AStat('$absent', 'Absent', Colors.white.withOpacity(0.8)),
                _AStat('$pct%', 'Rate', Colors.white),
              ],
            ),
          ).animate().fadeIn(duration: 280.ms),

          const SizedBox(height: 28),
          Row(children: [
            Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Quick Actions',
                style: AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),

          ...actions.asMap().entries.map((e) {
            final (icon, title, sub, color, onTap) = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withOpacity(0.22), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: color, size: 30),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppTypography.titleSmall
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(sub,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              )),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: color, size: 18),
                    ),
                  ]),
                ),
              )
                  .animate(delay: Duration(milliseconds: 80 * e.key))
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.06, end: 0),
            );
          }),
        ],
      ),
    );
  }
}

class _AStat extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _AStat(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: AppTypography.titleSmall
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(lbl,
            style: AppTypography.caption.copyWith(color: col.withOpacity(0.8))),
      ]);
}

// -------------------------------------------------------------------
// SCANNER ATTENDANCE SCREEN
// -------------------------------------------------------------------

class _ScannerAttendanceScreen extends StatefulWidget {
  final String className;
  const _ScannerAttendanceScreen({required this.className});
  @override
  State<_ScannerAttendanceScreen> createState() =>
      _ScannerAttendanceScreenState();
}

class _ScannerAttendanceScreenState extends State<_ScannerAttendanceScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  String? _lastCode;
  bool _showSuccess = false;
  int _scannedCount = 0;

  static const _mockStudents = <String, (String, String)>{};

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastCode) return;
    setState(() {
      _lastCode = code;
      _showSuccess = true;
      _scannedCount++;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSuccess = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = _mockStudents[_lastCode];
    final name = student?.$1 ?? (_lastCode ?? '');
    final roll = student?.$2 ?? 'Scanned ID';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scanner \u2014 ${widget.className}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.flash_on_rounded),
              onPressed: _scanner.toggleTorch),
          IconButton(
              icon: const Icon(Icons.cameraswitch_rounded),
              onPressed: _scanner.switchCamera),
        ],
      ),
      body: Stack(children: [
        // Camera
        MobileScanner(controller: _scanner, onDetect: _onDetect),

        // Scan frame outline
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border:
                  Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(children: [
              Positioned(top: 0, left: 0, child: _ScanCorner(topLeft: true)),
              Positioned(top: 0, right: 0, child: _ScanCorner(topRight: true)),
              Positioned(
                  bottom: 0, left: 0, child: _ScanCorner(bottomLeft: true)),
              Positioned(
                  bottom: 0, right: 0, child: _ScanCorner(bottomRight: true)),
            ]),
          ),
        ),

        // Hint text
        Positioned(
          bottom: 220,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Align QR code or Barcode within frame',
                style: AppTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),

        // Counter
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_scannedCount Scanned',
              style: AppTypography.labelSmall.copyWith(color: Colors.white),
            ),
          ),
        ),

        // Success panel (slides up)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _showSuccess ? 0 : -240,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Student detected' : name,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(roll,
                        style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55),
                        )),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.check_rounded,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      Text('Marked Present',
                          style: AppTypography.labelSmall
                              .copyWith(color: AppColors.success)),
                    ]),
                  ],
                ),
              ),
            ]),
          ).animate(target: _showSuccess ? 1 : 0).fadeIn(duration: 200.ms),
        ),
      ]),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _ScanCorner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(26, 26),
        painter: _CornerPainter(
          AppColors.success,
          3.0,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      );
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double sw;
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _CornerPainter(this.color, this.sw,
      {this.topLeft = false,
      this.topRight = false,
      this.bottomLeft = false,
      this.bottomRight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final s = size.width;
    if (topLeft) {
      canvas.drawLine(Offset(0, s), const Offset(0, 0), p);
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), p);
    }
    if (topRight) {
      canvas.drawLine(Offset(s, s), Offset(s, 0), p);
      canvas.drawLine(Offset(s, 0), const Offset(0, 0), p);
    }
    if (bottomLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(0, s), p);
      canvas.drawLine(Offset(0, s), Offset(s, s), p);
    }
    if (bottomRight) {
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), p);
      canvas.drawLine(Offset(s, 0), Offset(s, s), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// -------------------------------------------------------------------
// MANUAL ATTENDANCE SCREEN
// -------------------------------------------------------------------

class _ManualAttendanceScreen extends StatefulWidget {
  final String className;
  final int total;
  const _ManualAttendanceScreen({required this.className, required this.total});
  @override
  State<_ManualAttendanceScreen> createState() =>
      _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<_ManualAttendanceScreen> {
  static const _green = AppColors.success;

  late final List<_StuEntry> _students;

  @override
  void initState() {
    super.initState();
    _students = [];
  }

  int get _presentCount => _students.where((s) => s.present).length;

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Saved \u2014 $_presentCount / ${_students.length} present'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final absent = _students.length - _presentCount;
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual \u2014 ${widget.className}'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // Status strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: _green.withOpacity(0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ManStat('${_students.length}', 'Total', Colors.black87),
              _ManStat('$_presentCount', 'Present', _green),
              _ManStat('$absent', 'Absent', Colors.redAccent),
            ],
          ),
        ),

        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _students.forEach((s) => s.present = true)),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark All Present'),
                style: OutlinedButton.styleFrom(foregroundColor: _green),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]),
        ),

        const Divider(height: 1),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _students.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final s = _students[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: s.present
                      ? _green.withOpacity(0.12)
                      : Colors.redAccent.withOpacity(0.1),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0] : '?',
                    style: AppTypography.labelLarge.copyWith(
                      color: s.present ? _green : Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(s.name, style: AppTypography.labelMedium),
                subtitle: Text(s.roll,
                    style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5))),
                trailing: Transform.scale(
                  scale: 0.9,
                  child: Switch.adaptive(
                    value: s.present,
                    onChanged: (v) => setState(() => s.present = v),
                    activeColor: _green,
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _StuEntry {
  final String roll, name;
  bool present;
  _StuEntry({required this.roll, required this.name, required this.present});
}

class _ManStat extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _ManStat(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: AppTypography.titleSmall
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        Text(lbl, style: AppTypography.caption),
      ]);
}

// -------------------------------------------------------------------
// VIEW ATTENDANCE SCREEN
// -------------------------------------------------------------------

class _ViewAttendanceScreen extends StatefulWidget {
  final String className;
  const _ViewAttendanceScreen({required this.className});
  @override
  State<_ViewAttendanceScreen> createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<_ViewAttendanceScreen> {
  static const _green = AppColors.success;
  DateTime _selected = DateTime.now();

  static final List<_AttRecord> _records = [];

  static String _wd(int d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  static String _mn(int m) => const [
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
        'Dec'
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    final sel = _records.firstWhere(
      (r) =>
          r.date.day == _selected.day &&
          r.date.month == _selected.month &&
          r.date.year == _selected.year,
      orElse: () => _records.first,
    );
    final absent = sel.total - sel.present;
    final pct = (sel.present / sel.total * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('View \u2014 ${widget.className}'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // Date selector bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _green.withOpacity(0.06),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_wd(_selected.weekday)}, ${_selected.day} ${_mn(_selected.month)} ${_selected.year}',
                style: AppTypography.labelMedium
                    .copyWith(color: _green, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _selected,
                  firstDate: DateTime.now().subtract(const Duration(days: 180)),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: Theme.of(ctx)
                            .colorScheme
                            .copyWith(primary: _green)),
                    child: child!,
                  ),
                );
                if (p != null) setState(() => _selected = p);
              },
              child: const Text('Change'),
            ),
          ]),
        ),

        // Summary
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _green.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AStat('${sel.total}', 'Total', Colors.white),
                _AStat('${sel.present}', 'Present', Colors.white),
                _AStat('$absent', 'Absent', Colors.white.withOpacity(0.8)),
                _AStat('$pct%', 'Rate', Colors.white),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Last 14 Days',
                style: AppTypography.labelLarge
                    .copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = _records[i];
              final ab = r.total - r.present;
              final pc = (r.present / r.total * 100).round();
              final isSel = r.date.day == _selected.day &&
                  r.date.month == _selected.month &&
                  r.date.year == _selected.year;
              return InkWell(
                onTap: () => setState(() => _selected = r.date),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _green.withOpacity(0.08)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel
                          ? _green.withOpacity(0.3)
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.15),
                    ),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${_wd(r.date.weekday)}, ${r.date.day} ${_mn(r.date.month)}',
                            style: AppTypography.labelMedium)),
                    _SBadge('${r.present}P', _green),
                    const SizedBox(width: 6),
                    _SBadge('${ab}A', Colors.redAccent),
                    const SizedBox(width: 8),
                    Text('$pc%',
                        style: AppTypography.labelSmall.copyWith(
                            color: _green, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn();
            },
          ),
        ),
      ]),
    );
  }
}

class _AttRecord {
  final DateTime date;
  final int total, present;
  const _AttRecord(
      {required this.date, required this.total, required this.present});
}

class _SBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: AppTypography.caption
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

// ═══════════════════════════════════════════════════════════════════
// PRINCIPAL PROFILE SCREEN  (Profile tab)
// ═══════════════════════════════════════════════════════════════════

class PrincipalProfileScreen extends StatelessWidget {
  const PrincipalProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const SharedUserProfileScreen();
}

// ═══════════════════════════════════════════════════════════════════
// PRINCIPAL DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class PrincipalDashboardScreen extends StatefulWidget {
  const PrincipalDashboardScreen({super.key});

  @override
  State<PrincipalDashboardScreen> createState() =>
      _PrincipalDashboardScreenState();
}

class _PrincipalDashboardScreenState extends State<PrincipalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Reload on every visit so Excel imports are visible immediately
    SchoolDataStore.instance.reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolDataStore.instance,
      builder: (context, _) {
        final store = SchoolDataStore.instance;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 168,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    tooltip: 'Share App',
                    onPressed: () => Share.share(
                      'EduMid – India\'s #1 School ID Card App 🎓\nInstall now: https://edumid.app',
                      subject: 'Check out EduMid App!',
                    ),
                  ),
                  NotificationBadge(
                    count: NotificationStore.unreadCount,
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _PrincipalSchoolStatsScreen(),
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_rounded,
                                        color: Colors.white,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Good Morning 👋',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                  color: Colors.white
                                                      .withOpacity(0.8)),
                                        ),
                                        Text(
                                          '–',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          'Principal',
                                          style: AppTypography.caption.copyWith(
                                              color: Colors.white
                                                  .withOpacity(0.65)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_full_rounded,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SchoolStat(
                                        label: 'Students',
                                        value: '${store.studentCount}'),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _SchoolStat(
                                        label: 'Cards Issued', value: '–'),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _SchoolStat(
                                        label: 'Proofs', value: '–'),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _SchoolStat(
                                        label: 'Staff Cards',
                                        value: '${store.staffCount}'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Summary cards ──────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.people_rounded,
                            label: 'Total Students',
                            value: '${store.studentCount}',
                            color: AppColors.primary,
                            onTap: () => context.go('/principal/data'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.badge_rounded,
                            label: 'Cards Issued',
                            value: '–',
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.pending_actions_rounded,
                            label: 'Pending Proofs',
                            value: '–',
                            color: AppColors.warning,
                            onTap: () =>
                                context.go('/principal/proof-approval'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.person_pin_rounded,
                            label: 'Staff Cards',
                            value: '${store.staffCount}',
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),

                    // ── Pending proofs alert ───────────────────────
                    GraduientAlertBanner(
                      icon: Icons.pending_actions_rounded,
                      title: 'Proofs Awaiting Your Approval',
                      subtitle: 'Review and approve to proceed with printing',
                      color: AppColors.accent,
                      onTap: () => context.go('/principal/proof-approval'),
                    ).animate().fadeIn(delay: 250.ms),
                    const SizedBox(height: 20),

                    // ── Attendance Overview ────────────────────────
                    SectionHeader(
                      title: "Today's Attendance",
                      action: 'View All',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const _AttendanceOverviewScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AttendanceRow(
                            label: 'Students',
                            present: 0,
                            total: store.studentCount,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 14),
                          _AttendanceRow(
                            label: 'Teachers',
                            present: 0,
                            total: store.teacherCount,
                            color: AppColors.roleTeacher,
                          ),
                          const SizedBox(height: 14),
                          _AttendanceRow(
                            label: 'Staff',
                            present: 0,
                            total: store.staffCount,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 380.ms),
                    const SizedBox(height: 20),

                    // ── Quick Actions ──────────────────────────────
                    SectionHeader(title: 'Quick Actions'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PrincipalActionCard(
                            icon: Icons.badge_outlined,
                            label: 'Create\nID Card',
                            color: AppColors.primary,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28)),
                              ),
                              builder: (_) => const _CreateIDCardSheet(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrincipalActionCard(
                            icon: Icons.manage_accounts_rounded,
                            label: 'Restrict &\nLogout Users',
                            color: AppColors.error,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const _UserManagementScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 12),
                    // Monitor Activity — full-width card
                    _PrincipalActionCard(
                      icon: Icons.bar_chart_rounded,
                      label: 'Monitor App Activity',
                      color: AppColors.primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const _AppActivityScreen(),
                        ),
                      ),
                    ).animate().fadeIn(delay: 450.ms),
                    const SizedBox(height: 12),
                    // Purchase Orders + Direct Link row
                    Row(
                      children: [
                        Expanded(
                          child: _PrincipalActionCard(
                            icon: Icons.shopping_cart_rounded,
                            label: 'Purchase\nOrders',
                            color: const Color(0xFFD97706),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const _PurchaseOrderScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrincipalActionCard(
                            icon: Icons.link_rounded,
                            label: 'Generate\nDirect Link',
                            color: const Color(0xFF4F46E5),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const _DirectLinkScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 12),
                    // Order Requests + Reprint Requests row
                    Row(
                      children: [
                        Expanded(
                          child: _PrincipalActionCard(
                            icon: Icons.inbox_rounded,
                            label: 'Order\nRequests',
                            color: AppColors.primary,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const _PrincipalOrderRequestsScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrincipalActionCard(
                            icon: Icons.print_rounded,
                            label: 'Reprint\nRequests',
                            color: AppColors.warning,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const _ReprintRequestsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 550.ms),
                    const SizedBox(height: 20),

                    // ── Recent Approvals ───────────────────────────
                    SectionHeader(
                      title: 'Recent Approvals',
                      action: 'View All',
                      onAction: () => context.go('/principal/proof-approval'),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SchoolStat extends StatelessWidget {
  final String label;
  final String value;
  const _SchoolStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.titleSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrincipalActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PrincipalActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppTypography.labelSmall, textAlign: TextAlign.center),
        ],
      ),
      padding: const EdgeInsets.all(14),
    );
  }
}

Widget GraduientAlertBanner({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelLarge.copyWith(color: color)),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    ),
  );
}

// ── Create ID Card Sheet ──────────────────────────────────────────
class _CreateIDCardSheet extends StatefulWidget {
  const _CreateIDCardSheet();

  @override
  State<_CreateIDCardSheet> createState() => _CreateIDCardSheetState();
}

class _CreateIDCardSheetState extends State<_CreateIDCardSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Student';
  String? _selectedBloodGroup;
  bool _generating = false;
  late Future<List<Map<String, dynamic>>> _submissionsFuture;

  final _nameCtrl = TextEditingController();
  final _classDeptCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  // Custom additional fields added by the principal — scoped per card type
  final Map<String, List<_CustomField>> _customFieldsByType = {
    'Student': [],
    'Teacher': [],
    'Staff': [],
  };

  List<_CustomField> get _customFields => _customFieldsByType[_selectedType]!;

  static const _types = ['Student', 'Teacher', 'Staff'];
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  // Suggested field names for quick pick
  static const _suggestedFields = [
    'Father\'s Name',
    'Mother\'s Name',
    'Guardian\'s Name',
    'Address',
    'Date of Birth',
    'Aadhar Number',
    'Emergency Contact',
    'Bus Route',
    'House / Wing',
    'Nationality',
  ];

  @override
  void initState() {
    super.initState();
    _submissionsFuture = _loadSubmittedForms();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classDeptCtrl.dispose();
    _idCtrl.dispose();
    _mobileCtrl.dispose();
    for (final fields in _customFieldsByType.values) {
      for (final f in fields) {
        f.controller.dispose();
      }
    }
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadSubmittedForms() async {
    try {
      final list = await IdCardFormService().getFormSubmissions(
        principalId: _kPrincipalId,
        role: 'all',
      );
      final filtered = list.where((s) {
        final role = (s['role']?.toString() ?? '').toLowerCase();
        return role == 'student' || role == 'teacher';
      }).toList();
      filtered.sort((a, b) {
        final da = DateTime.tryParse(a['submittedAt']?.toString() ?? '') ??
            DateTime(2000);
        final db = DateTime.tryParse(b['submittedAt']?.toString() ?? '') ??
            DateTime(2000);
        return db.compareTo(da);
      });
      return filtered;
    } catch (_) {
      return [];
    }
  }

  Widget _buildSubmissionPreview(Map<String, dynamic> formData) {
    final entries = formData.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) {
      return Text(
        'No form data',
        style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.take(5).map((e) {
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${e.key}: ${e.value}',
            style: AppTypography.caption,
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(dynamic date) {
    final parsed = DateTime.tryParse(date?.toString() ?? '');
    if (parsed == null) return 'N/A';
    final dt = parsed.toLocal();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  /// Save the custom fields as a form structure that's accessible to all roles
  /// Save the custom fields as a form structure that's accessible to all roles
  /// Returns true when saved successfully
  Future<bool> _saveFormStructure() async {
    try {
      // Build minimal form fields structure (label, type, required)
      final formFieldsList = _customFields
          .asMap()
          .entries
          .map(
            (entry) => IdCardFormField(
              fieldId: 'custom_${entry.key}',
              fieldName: entry.value.label,
              fieldType: 'text',
              isRequired: true,
              order: entry.key,
            ),
          )
          .toList();

      print("🔥 Sending POST request");
      final savedId = await IdCardFormService().saveIdCardForm(
        principalId: _kPrincipalId,
        formFields: formFieldsList,
        formTitle: 'ID Card Form',
      );
      if (savedId != null && savedId.isNotEmpty) {
        print('✅ Form saved with id: $savedId');
        return true;
      }
      print('❌ API ERROR: save returned null');
      return false;
    } catch (e, st) {
      print('[CreateIDCardSheet] ❌ Error preparing form payload: $e');
      print(st);
      return false;
    }
  }

  // Show dialog to pick/type a new field name
  void _showAddFieldDialog() {
    final customCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Custom Field'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type your own
                    TextField(
                      controller: customCtrl,
                      decoration: InputDecoration(
                        hintText: 'Field label (e.g. Father\'s Name)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Text('Quick suggestions:',
                        style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                    const SizedBox(height: 8),
                    // Filter out already-added suggestions
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedFields
                          .where((s) => !_customFields.any(
                              (f) => f.label.toLowerCase() == s.toLowerCase()))
                          .map((s) => GestureDetector(
                                onTap: () {
                                  Navigator.of(dialogCtx).pop();
                                  _addField(s);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.25)),
                                  ),
                                  child: Text(s,
                                      style: AppTypography.labelSmall
                                          .copyWith(color: AppColors.primary)),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: customCtrl.text.trim().isEmpty
                      ? null
                      : () {
                          Navigator.of(dialogCtx).pop();
                          _addField(customCtrl.text.trim());
                        },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addField(String label) {
    setState(() {
      _customFieldsByType[_selectedType]!.add(_CustomField(
        label: label,
        controller: TextEditingController(),
      ));
    });
  }

  void _removeField(int index) {
    setState(() {
      _customFieldsByType[_selectedType]![index].controller.dispose();
      _customFieldsByType[_selectedType]!.removeAt(index);
    });
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title row
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.badge_outlined, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Create ID Card',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),
              // Card type chips
              Text('Card Type',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: _types.map((t) {
                  final sel = _selectedType == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? color
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.4)),
                        ),
                        child: Text(
                          t,
                          style: AppTypography.labelSmall.copyWith(
                            color: sel
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              // Photo placeholder
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 88,
                    height: 104,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded,
                            color: color.withOpacity(0.6), size: 26),
                        const SizedBox(height: 6),
                        Text('Add Photo',
                            style: AppTypography.caption
                                .copyWith(color: color.withOpacity(0.65))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // ── Standard fields ────────────────────────────
              _field('Full Name', _nameCtrl, hint: 'e.g. Ravi Kumar'),
              _field(
                _selectedType == 'Student' ? 'Class & Section' : 'Department',
                _classDeptCtrl,
                hint: _selectedType == 'Student' ? 'e.g. X-A' : 'e.g. Science',
              ),
              _field(
                _selectedType == 'Student' ? 'Roll Number' : 'Employee ID',
                _idCtrl,
                hint: _selectedType == 'Student' ? 'e.g. 1024' : 'e.g. EMP-042',
              ),
              // Blood Group
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: _selectedBloodGroup,
                  decoration: InputDecoration(
                    labelText: 'Blood Group',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: _bloodGroups
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBloodGroup = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              _field(
                'Mobile Number',
                _mobileCtrl,
                keyboardType: TextInputType.phone,
                hint: 'e.g. 9876543210',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 10) return 'Enter a valid number';
                  return null;
                },
              ),
              // ── Custom fields ──────────────────────────────
              if (_customFields.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.tune_rounded,
                      size: 16, color: color.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text('Custom Fields',
                      style: AppTypography.labelMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                ..._customFields.asMap().entries.map((e) {
                  final i = e.key;
                  final f = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: f.controller,
                            decoration: InputDecoration(
                              labelText: f.label,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              suffixIcon: Icon(Icons.edit_note_rounded,
                                  size: 18, color: color.withOpacity(0.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Remove field button
                        GestureDetector(
                          onTap: () => _removeField(i),
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.error.withOpacity(0.25)),
                            ),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              // ── Add Field button ───────────────────────────
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _showAddFieldDialog,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          size: 18, color: color),
                      const SizedBox(width: 8),
                      Text(
                        'Add Custom Field',
                        style: AppTypography.labelMedium.copyWith(
                            color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _generating
                      ? null
                      : () async {
                          setState(() => _generating = true);
                          final success = await _saveFormStructure();
                          if (!mounted) return;

                          if (success) {
                            // Re-fetch latest form to update UI
                            try {
                              await IdCardFormService()
                                  .getIdCardForm(principalId: _kPrincipalId);
                              setState(() {
                                _submissionsFuture = _loadSubmittedForms();
                              });
                            } catch (e) {
                              // ignore fetch errors here; we still show success
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Form saved successfully'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            // Keep sheet open so principal can review submitted forms below
                          }

                          if (mounted) setState(() => _generating = false);
                        },
                  icon: _generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.badge_outlined, size: 18),
                  label: Text(_generating ? 'Saving…' : 'Set Form'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded,
                      size: 18, color: color.withOpacity(0.85)),
                  const SizedBox(width: 8),
                  Text(
                    'Submitted Forms (Students & Teachers)',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh submissions',
                    onPressed: () {
                      setState(() {
                        _submissionsFuture = _loadSubmittedForms();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _submissionsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final data = snap.data ?? [];
                  if (data.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.18)),
                      ),
                      child: Text(
                        'No teacher/student submissions yet.',
                        style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.65),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final sub = data[i];
                      final formData =
                          Map<String, dynamic>.from(sub['formData'] ?? {});
                      final role =
                          (sub['role']?.toString() ?? 'unknown').toUpperCase();
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub['userName']?.toString().isNotEmpty == true
                                  ? sub['userName'].toString()
                                  : 'Unknown User',
                              style: AppTypography.labelMedium
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$role • ${_formatDate(sub['submittedAt'])}',
                              style: AppTypography.caption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildSubmissionPreview(formData),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Model for a principal-defined custom field
class _CustomField {
  final String label;
  final TextEditingController controller;
  const _CustomField({required this.label, required this.controller});
}

// ── User Management Screen (Restrict / Force Logout) ─────────────
class _UserManagementScreen extends StatefulWidget {
  const _UserManagementScreen();

  @override
  State<_UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<_UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'All';
  static const _filters = ['All', 'Active', 'Restricted'];

  List<_ManagedUser> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _principalDio().get(
        '$_kPrincipalBase/api/principal/users',
        queryParameters: {'principalId': _kPrincipalId},
      );
      final data = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _users = data.map((m) {
          final type = (m['type'] as String?) ?? '';
          final isTeacher = type == 'teacher';
          final dept = (m['classOrDept'] as String?) ?? '';
          final isRestricted = (m['isRestricted'] as bool?) ?? false;
          final isActive = (m['isActive'] as bool?) ?? !isRestricted;
          return _ManagedUser(
            id: m['id'].toString(),
            name: (m['name'] as String?) ?? '',
            subtitle: isTeacher
                ? (dept.isEmpty ? 'Teacher' : dept)
                : (dept.isEmpty ? 'Staff' : dept),
            role: isTeacher ? 'Teacher' : 'Staff',
            isRestricted: isRestricted,
            isActive: isActive,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load users';
        _isLoading = false;
      });
      debugPrint('[UserMgmt] load error: $e');
    }
  }

  List<_ManagedUser> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _users.where((u) {
      final matchesFilter = _filter == 'All' ||
          (_filter == 'Active' && u.isActive && !u.isRestricted) ||
          (_filter == 'Restricted' && u.isRestricted);
      final matchesSearch = q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.subtitle.toLowerCase().contains(q);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  void _toggleRestrict(_ManagedUser user) {
    final willRestrict = !user.isRestricted;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(willRestrict ? 'Restrict Access' : 'Restore Access'),
        content: Text(willRestrict
            ? 'Restrict ${user.name}? They will no longer be able to log in.'
            : 'Restore access for ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              // Optimistic update
              setState(() {
                final i = _users.indexWhere((u) => u.id == user.id);
                if (i != -1) {
                  _users[i] = user.copyWith(isRestricted: willRestrict);
                }
              });
              try {
                await _principalDio().patch(
                  '$_kPrincipalBase/api/principal/members/${user.id}/restrict',
                  data: {'isRestricted': willRestrict},
                );
                await _loadUsers();
              } catch (e) {
                // Revert on failure
                if (mounted) {
                  setState(() {
                    final i = _users.indexWhere((u) => u.id == user.id);
                    if (i != -1) {
                      _users[i] = user.copyWith(isRestricted: !willRestrict);
                    }
                  });
                }
                debugPrint('[UserMgmt] restrict error: $e');
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(willRestrict
                    ? '${user.name} has been restricted'
                    : '${user.name} access restored'),
                backgroundColor:
                    willRestrict ? AppColors.error : AppColors.success,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor:
                    willRestrict ? AppColors.error : AppColors.success),
            child: Text(willRestrict ? 'Restrict' : 'Restore'),
          ),
        ],
      ),
    );
  }

  void _forceLogout(_ManagedUser user) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Force Logout'),
        content: Text(
            'Force logout ${user.name}? Their active session will be terminated immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              try {
                await _principalDio().post(
                  '$_kPrincipalBase/api/principal/members/${user.id}/force-logout',
                );
                await _loadUsers();
              } catch (e) {
                debugPrint('[UserMgmt] force-logout error: $e');
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${user.name} has been force logged out'),
                backgroundColor: AppColors.warning,
              ));
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Force Logout'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Teacher':
        return AppColors.roleTeacher;
      case 'Staff':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 60, color: AppColors.error.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(_error!, style: AppTypography.titleSmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              ),
            ],
          ),
        ),
      );
    }
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name or role…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final sel = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.error : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AppColors.error
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      f,
                      style: AppTypography.labelSmall.copyWith(
                        color: sel
                            ? Colors.white
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Count row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${list.length} users',
                  style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5)),
                ),
                const Spacer(),
                Text(
                  '${_users.where((u) => u.isRestricted).length} restricted',
                  style:
                      AppTypography.bodySmall.copyWith(color: AppColors.error),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // User list
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_rounded,
                            size: 64, color: AppColors.error.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('No users found',
                            style: AppTypography.titleSmall.copyWith(
                                color: AppColors.error.withOpacity(0.6))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final user = list[i];
                      final rc = _roleColor(user.role);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: user.isRestricted
                              ? AppColors.error.withOpacity(0.05)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: user.isRestricted
                                ? AppColors.error.withOpacity(0.25)
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.15),
                          ),
                        ),
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: rc.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(user.name[0],
                                  style: AppTypography.labelLarge
                                      .copyWith(color: rc)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name,
                                    style: AppTypography.labelMedium),
                                Text(
                                  user.subtitle,
                                  style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          // Actions column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: user.isRestricted
                                      ? AppColors.error.withOpacity(0.1)
                                      : AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: user.isRestricted
                                          ? AppColors.error.withOpacity(0.35)
                                          : AppColors.success
                                              .withOpacity(0.35)),
                                ),
                                child: Text(
                                  user.isRestricted
                                      ? 'Restricted'
                                      : (user.isActive
                                          ? 'Active'
                                          : 'Logged Out'),
                                  style: AppTypography.caption.copyWith(
                                    color: user.isRestricted
                                        ? AppColors.error
                                        : (user.isActive
                                            ? AppColors.success
                                            : AppColors.warning),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Action buttons row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Restrict / Restore button
                                  GestureDetector(
                                    onTap: () => _toggleRestrict(user),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: user.isRestricted
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: user.isRestricted
                                              ? AppColors.success
                                                  .withOpacity(0.35)
                                              : AppColors.error
                                                  .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            user.isRestricted
                                                ? Icons.lock_open_rounded
                                                : Icons.block_rounded,
                                            size: 12,
                                            color: user.isRestricted
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            user.isRestricted
                                                ? 'Restore'
                                                : 'Restrict',
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: user.isRestricted
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Force Logout button
                                  GestureDetector(
                                    onTap: user.isActive
                                        ? () => _forceLogout(user)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: user.isActive
                                            ? AppColors.warning.withOpacity(0.1)
                                            : Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: user.isActive
                                                ? AppColors.warning
                                                    .withOpacity(0.35)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withOpacity(0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.logout_rounded,
                                              size: 12,
                                              color: user.isActive
                                                  ? AppColors.warning
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.45)),
                                          const SizedBox(width: 4),
                                          Text('Logout',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: user.isActive
                                                    ? AppColors.warning
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.45),
                                                fontWeight: FontWeight.w600,
                                              )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ManagedUser {
  final String id;
  final String name;
  final String subtitle;
  final String role; // 'Teacher' | 'Staff'
  final bool isRestricted;
  final bool isActive;

  const _ManagedUser({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.role,
    required this.isRestricted,
    required this.isActive,
  });

  _ManagedUser copyWith({bool? isRestricted, bool? isActive}) => _ManagedUser(
        id: id,
        name: name,
        subtitle: subtitle,
        role: role,
        isRestricted: isRestricted ?? this.isRestricted,
        isActive: isActive ?? this.isActive,
      );
}

// ── App Activity Monitor Screen ───────────────────────────────────
class _AppActivityScreen extends StatefulWidget {
  const _AppActivityScreen();

  @override
  State<_AppActivityScreen> createState() => _AppActivityScreenState();
}

class _AppActivityScreenState extends State<_AppActivityScreen> {
  String _filter = 'All';
  static const _filters = ['All', 'Teacher', 'Staff'];
  static const _purple = AppColors.primary;

  static final _activities = <_UserActivity>[];

  List<_UserActivity> get _filtered {
    if (_filter == 'All') return _activities;
    return _activities.where((a) => a.role == _filter).toList();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final onlineCount = _activities.where((a) => a.isOnline).length;
    final totalMinutes = _activities.fold(0, (sum, a) => sum + a.minutesActive);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Activity Monitor'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stat cards
            Row(children: [
              Expanded(
                child: _StatMini(
                  label: 'Online Now',
                  value: '$onlineCount',
                  icon: Icons.circle,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  label: 'Total Active',
                  value: '${_activities.length}',
                  icon: Icons.people_rounded,
                  color: _purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  label: 'Active Mins',
                  value: '$totalMinutes',
                  icon: Icons.timer_rounded,
                  color: AppColors.primary,
                ),
              ),
            ]),
            const SizedBox(height: 18),
            // Filter chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final sel = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _purple : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? _purple
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        f,
                        style: AppTypography.labelSmall.copyWith(
                          color: sel
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            // User cards
            ...list.map((u) => _UserActivityCard(user: u)),
          ],
        ),
      ),
    );
  }
}

class _UserActivityCard extends StatelessWidget {
  final _UserActivity user;
  const _UserActivityCard({required this.user});
  static const _purple = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isOnline
              ? AppColors.success.withOpacity(0.25)
              : Theme.of(context).colorScheme.outline.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(user.name[0],
                      style:
                          AppTypography.labelLarge.copyWith(color: _purple))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: AppTypography.labelMedium),
                  Text(user.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
                ],
              ),
            ),
            // Online / offline badge
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: user.isOnline
                      ? AppColors.success
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                user.isOnline ? 'Online' : 'Offline',
                style: AppTypography.caption.copyWith(
                  color: user.isOnline
                      ? AppColors.success
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 10),
          // Last login
          Row(children: [
            Icon(Icons.login_rounded,
                size: 13, color: _purple.withOpacity(0.6)),
            const SizedBox(width: 5),
            Text('Last login: ${user.lastLogin}',
                style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55))),
          ]),
          const SizedBox(height: 10),
          // Stats row
          Row(children: [
            _ActivityMiniStat(
                icon: Icons.timer_rounded,
                label: '${user.minutesActive} min active',
                color: AppColors.primary),
          ]),
          const SizedBox(height: 10),
          // Activity bar (minutes active as % of 240 min workday)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (user.minutesActive / 240).clamp(0.0, 1.0),
              color: user.isOnline ? AppColors.success : _purple,
              backgroundColor: _purple.withOpacity(0.08),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${((user.minutesActive / 240) * 100).toInt()}% of workday active',
            style: AppTypography.caption.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

class _ActivityMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ActivityMiniStat(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatMini(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: AppTypography.labelMedium
                .copyWith(color: color, fontWeight: FontWeight.w700)),
        Text(label,
            style: AppTypography.caption.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _UserActivity {
  final String name;
  final String subtitle;
  final String role;
  final String lastLogin;
  final bool isOnline;
  final int dataProcessed;
  final int tasksCompleted;
  final int minutesActive;
  final List<String> logins;
  final List<(String, String)> actions;

  const _UserActivity(
    this.name,
    this.subtitle,
    this.role, {
    required this.lastLogin,
    required this.isOnline,
    required this.dataProcessed,
    required this.tasksCompleted,
    required this.minutesActive,
    required this.logins,
    required this.actions,
  });
}

// ═══════════════════════════════════════════════════════════════════
// ATTENDANCE OVERVIEW
// ═══════════════════════════════════════════════════════════════════

/// Compact row: label + progress bar + "present / total (xx%)" text.
class _AttendanceRow extends StatelessWidget {
  final String label;
  final int present;
  final int total;
  final Color color;

  const _AttendanceRow({
    required this.label,
    required this.present,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : present / total;
    final pctText = '${(pct * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.labelMedium),
            Text(
              '$present / $total ($pctText)',
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// Full-screen attendance breakdown by class/group.
class _AttendanceOverviewScreen extends StatefulWidget {
  const _AttendanceOverviewScreen();

  @override
  State<_AttendanceOverviewScreen> createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<_AttendanceOverviewScreen> {
  String _filter = 'All';

  static const _filters = ['All', 'Students', 'Teachers', 'Staff'];

  // Mock data
  static const _studentClasses = <_ClassAttendance>[];

  static const _teacherDepts = <_ClassAttendance>[];

  static const _staffGroups = <_ClassAttendance>[];

  List<_ClassAttendance> get _rows {
    switch (_filter) {
      case 'Students':
        return _studentClasses;
      case 'Teachers':
        return _teacherDepts;
      case 'Staff':
        return _staffGroups;
      default:
        return [..._studentClasses, ..._teacherDepts, ..._staffGroups];
    }
  }

  Color _colorFor(_ClassAttendance row) {
    if (_teacherDepts.contains(row)) return AppColors.roleTeacher;
    if (_staffGroups.contains(row)) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final totalPresent = rows.fold(0, (s, r) => s + r.present);
    final totalTotal = rows.fold(0, (s, r) => s + r.total);
    final overallPct = totalTotal == 0 ? 0 : (totalPresent * 100 ~/ totalTotal);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Today's Attendance"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttendanceStat(
                    label: 'Present',
                    value: '$totalPresent',
                    color: Colors.white),
                _AttendanceStat(
                    label: 'Absent',
                    value: '${totalTotal - totalPresent}',
                    color: Colors.white),
                _AttendanceStat(
                    label: 'Overall',
                    value: '$overallPct%',
                    color: Colors.white),
              ],
            ),
          ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _filters.map((f) {
                final selected = f == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final row = rows[i];
                final color = _colorFor(row);
                return PremiumCard(
                  child: _AttendanceRow(
                    label: row.name,
                    present: row.present,
                    total: row.total,
                    color: color,
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

class _AttendanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AttendanceStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTypography.titleLarge
                .copyWith(color: color, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style:
                AppTypography.caption.copyWith(color: color.withOpacity(0.85))),
      ],
    );
  }
}

@immutable
class _ClassAttendance {
  final String name;
  final int present;
  final int total;

  const _ClassAttendance(
      {required this.name, required this.present, required this.total});
}

// ═══════════════════════════════════════════════════════════════════
// PURCHASE ORDERS
// ═══════════════════════════════════════════════════════════════════

class _PurchaseOrderScreen extends StatefulWidget {
  const _PurchaseOrderScreen();

  @override
  State<_PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<_PurchaseOrderScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final principalId = await _ensurePrincipalId();

      // Get schoolCode from stored user — send alongside principalId so the
      // backend can also match by schoolCode directly (no extra DB round-trip).
      final user = await AuthService.instance.getStoredUser();
      final schoolCode =
          (user?['schoolCode'] ?? '').toString().trim().toUpperCase();

      debugPrint(
          '[PurchaseOrders] principalId=$principalId schoolCode=$schoolCode');

      if (principalId.isEmpty && schoolCode.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'Could not determine principal identity. Please log in again.';
        });
        return;
      }

      final params = <String, String>{};
      if (principalId.isNotEmpty) params['principalId'] = principalId;
      if (schoolCode.isNotEmpty) params['schoolCode'] = schoolCode;

      final res = await _principalDio().get(
        ApiConfig.principalPurchaseOrders,
        queryParameters: params,
      );
      debugPrint(
          '[PurchaseOrders] status=${res.statusCode} count=${(res.data as List?)?.length}');
      if (!mounted) return;
      final List<dynamic> raw = res.data as List<dynamic>;
      setState(() {
        _orders = raw.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PurchaseOrders] ERROR: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load purchase orders: $e';
        });
      }
    }
  }

  Color _stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in progress':
        return AppColors.primary;
      case 'draft':
        return Colors.grey;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('No purchase orders yet',
                              style: AppTypography.titleMedium.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5))),
                          const SizedBox(height: 8),
                          Text(
                            'Orders placed by your vendor will appear here.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.4)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          final stage = (o['stage'] as String?) ?? 'Draft';
                          final pricing = o['pricing'] as Map<String, dynamic>?;

                          String? deliveryStr;
                          if (o['deliveryDate'] != null) {
                            try {
                              final dt =
                                  DateTime.parse(o['deliveryDate'] as String);
                              deliveryStr =
                                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                            } catch (_) {}
                          }

                          return GestureDetector(
                            onTap: () {
                              debugPrint('[PurchaseOrders] Tapped order: $o');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _OrderDetailsScreen(order: o),
                                ),
                              );
                            },
                            child: PremiumCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (o['title'] as String?) ??
                                                  'Untitled Order',
                                              style: AppTypography.labelLarge
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700),
                                            ),
                                            if ((o['productType'] as String?)
                                                    ?.isNotEmpty ==
                                                true) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                o['productType'] as String,
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.55),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _stageColor(stage)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          stage,
                                          style: AppTypography.caption.copyWith(
                                            color: _stageColor(stage),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (pricing != null) ...[
                                    const SizedBox(height: 10),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        for (final entry in pricing.entries)
                                          if (entry.value != null)
                                            _PricingChip(
                                              label: entry.key,
                                              value: entry.value,
                                            ),
                                      ],
                                    ),
                                  ],
                                  if (deliveryStr != null) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Delivery: $deliveryStr',
                                          style: AppTypography.caption.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ); // GestureDetector
                        },
                      ),
                    ),
    );
  }
}

class _PricingChip extends StatelessWidget {
  final String label;
  final dynamic value;
  const _PricingChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display =
        value is num ? '₹${(value as num).toStringAsFixed(0)}' : '$value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        '${label[0].toUpperCase()}${label.substring(1)}: $display',
        style: AppTypography.caption
            .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ORDER DETAILS SCREEN
// ═══════════════════════════════════════════════════════════════════

class _OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderDetailsScreen({required this.order});

  Color _stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in progress':
        return AppColors.primary;
      case 'draft':
        return Colors.grey;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[OrderDetails] Order received: $order');

    final stage = (order['stage'] as String?) ?? 'Draft';
    final pricing = order['pricing'] as Map<String, dynamic>?;
    final images = order['images'] as List<dynamic>?;
    final description = (order['description'] as String?)?.trim() ?? '';
    final schoolName = (order['schoolName'] as String?) ?? '';
    final schoolCode = (order['schoolCode'] as String?) ?? '';
    final productType = (order['productType'] as String?) ?? '';
    final productName = (order['productName'] as String?) ?? '';
    final youtubeLink = (order['youtubeLink'] as String?) ?? '';
    final instagramLink = (order['instagramLink'] as String?) ?? '';

    String? deliveryStr;
    if (order['deliveryDate'] != null) {
      try {
        final dt = DateTime.parse(order['deliveryDate'] as String);
        deliveryStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ────────────────────────────────────────
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          (order['title'] as String?) ?? 'Untitled Order',
                          style: AppTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _stageColor(stage).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _stageColor(stage).withOpacity(0.3)),
                        ),
                        child: Text(
                          stage,
                          style: AppTypography.caption.copyWith(
                            color: _stageColor(stage),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (schoolName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.school_rounded,
                            size: 16,
                            color: AppColors.primary.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            schoolName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (schoolCode.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.fingerprint_rounded,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)),
                        const SizedBox(width: 6),
                        Text(
                          'Code: $schoolCode',
                          style: AppTypography.caption.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Product & Delivery ──────────────────────────────────
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Product',
                      style: AppTypography.labelLarge
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (productType.isNotEmpty)
                    _DetailRow(
                      icon: Icons.category_rounded,
                      label: 'Type',
                      value: productType,
                    ),
                  if (productName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.label_rounded,
                      label: 'Name',
                      value: productName,
                    ),
                  ],
                  if (deliveryStr != null) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Delivery',
                      value: deliveryStr,
                    ),
                  ],
                ],
              ),
            ),

            if (pricing != null && pricing.isNotEmpty) ...[
              const SizedBox(height: 12),
              // ── Pricing ─────────────────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pricing',
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    for (final entry in pricing.entries)
                      if (entry.value != null) ...[
                        _PricingRow(label: entry.key, value: entry.value),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ],

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              // ── Description ──────────────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description',
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(description, style: AppTypography.bodyMedium),
                  ],
                ),
              ),
            ],

            if (youtubeLink.isNotEmpty || instagramLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Links',
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (youtubeLink.isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.play_circle_rounded,
                        label: 'YouTube',
                        value: youtubeLink,
                        valueColor: Colors.red,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (instagramLink.isNotEmpty)
                      _DetailRow(
                        icon: Icons.photo_camera_rounded,
                        label: 'Instagram',
                        value: instagramLink,
                        valueColor: Colors.purple,
                      ),
                  ],
                ),
              ),
            ],

            if (images != null && images.isNotEmpty) ...[
              const SizedBox(height: 12),
              // ── Images ───────────────────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Images (${images.length})',
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: images.map((img) {
                        final url = img.toString();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            ApiConfig.resolveImageUrl(url),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: AppColors.primary.withOpacity(0.08),
                              child: const Icon(Icons.broken_image_rounded,
                                  color: Colors.grey),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              color: valueColor ??
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _PricingRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _PricingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display =
        value is num ? '₹${(value as num).toStringAsFixed(0)}' : '$value';
    final name = '${label[0].toUpperCase()}${label.substring(1)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(name, style: AppTypography.bodyMedium),
          ],
        ),
        Text(
          display,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DIRECT LINK GENERATOR
// ═══════════════════════════════════════════════════════════════════

class _DirectLinkScreen extends StatefulWidget {
  const _DirectLinkScreen();

  @override
  State<_DirectLinkScreen> createState() => _DirectLinkScreenState();
}

class _DirectLinkScreenState extends State<_DirectLinkScreen> {
  String _selectedType = 'Student Admission Form';
  String? _generatedLink;
  bool _generating = false;

  static const _linkTypes = [
    'Student Admission Form',
    'Staff Onboarding Form',
    'Fee Payment Portal',
    'ID Card Request',
    'Leave Application',
    'Document Submission',
  ];

  Future<void> _generateLink() async {
    setState(() {
      _generating = true;
      _generatedLink = null;
    });
    await Future.delayed(const Duration(seconds: 1));
    final slug = _selectedType
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    if (mounted) {
      setState(() {
        _generatedLink =
            'https://app.edumid.in/portal/$slug?token=${DateTime.now().millisecondsSinceEpoch}';
        _generating = false;
      });
    }
  }

  void _shareLink() {
    if (_generatedLink == null) return;
    Share.share(_generatedLink!, subject: 'Edumid Portal Link');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Generate Direct Link'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Form Type',
                      style: AppTypography.labelLarge
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ..._linkTypes.map((type) => GestureDetector(
                        onTap: () => setState(() {
                          _selectedType = type;
                          _generatedLink = null;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedType == type
                                ? const Color(0xFF4F46E5).withOpacity(0.1)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedType == type
                                  ? const Color(0xFF4F46E5)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.3),
                              width: _selectedType == type ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedType == type
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: _selectedType == type
                                    ? const Color(0xFF4F46E5)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.4),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(type,
                                  style: AppTypography.labelMedium.copyWith(
                                    fontWeight: _selectedType == type
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _selectedType == type
                                        ? const Color(0xFF4F46E5)
                                        : null,
                                  )),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _generating ? null : _generateLink,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.link_rounded),
                    label:
                        Text(_generating ? 'Generating...' : 'Generate Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            if (_generatedLink != null) ...[
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text('Link Generated',
                            style: AppTypography.labelLarge.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_generatedLink!,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF4F46E5))),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareLink,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINCIPAL ORDER REQUESTS
// ═══════════════════════════════════════════════════════════════════

class _PrincipalOrderRequestsScreen extends StatelessWidget {
  const _PrincipalOrderRequestsScreen();

  @override
  Widget build(BuildContext context) {
    final requests = OrderRequestStore.all;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Order Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No order requests yet',
                      style: AppTypography.titleMedium.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final req = requests[i];
                final statusColor = req.status == OrderStatus.approved
                    ? AppColors.success
                    : req.status == OrderStatus.rejected
                        ? Colors.red
                        : AppColors.warning;
                final statusLabel =
                    req.status.name.substring(0, 1).toUpperCase() +
                        req.status.name.substring(1);
                return PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(req.id,
                                style: AppTypography.labelLarge
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusLabel,
                                style: AppTypography.caption.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('By: ${req.teacherName}',
                          style: AppTypography.bodyMedium),
                      Text(
                          'RS.${req.totalPrice.toStringAsFixed(0)}  -  ${req.items.length} item${req.items.length == 1 ? '' : 's'}',
                          style: AppTypography.caption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6))),
                      if (req.status == OrderStatus.pending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  OrderRequestStore.reject(req.id);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  OrderRequestStore.approve(req.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// REPRINT REQUESTS
// ═══════════════════════════════════════════════════════════════════

class _ReprintRequestsScreen extends StatefulWidget {
  const _ReprintRequestsScreen();

  @override
  State<_ReprintRequestsScreen> createState() => _ReprintRequestsScreenState();
}

class _ReprintRequestsScreenState extends State<_ReprintRequestsScreen> {
  late final List<ReprintRequest> _requests;

  @override
  void initState() {
    super.initState();
    _requests = List.from(ReprintRepository.instance.requests);
  }

  void _updateStatus(String id, String status) {
    ReprintRepository.instance.updateStatus(id, status);
    setState(() {
      final idx = _requests.indexWhere((r) => r.id == id);
      if (idx != -1) _requests[idx].status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reprint Requests'),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No reprint requests',
                      style: AppTypography.titleMedium.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final req = _requests[i];
                final isPending = req.status == 'pending';
                final statusColor = req.status == 'approved'
                    ? AppColors.success
                    : req.status == 'rejected'
                        ? Colors.red
                        : AppColors.warning;
                final statusLabel = req.status.substring(0, 1).toUpperCase() +
                    req.status.substring(1);
                return PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(req.studentName,
                                style: AppTypography.labelLarge
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusLabel,
                                style: AppTypography.caption.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${req.className}  Roll: ${req.rollNo}',
                          style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6))),
                      Text(
                          'Requested: ${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}',
                          style: AppTypography.caption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5))),
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _updateStatus(req.id, 'rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _updateStatus(req.id, 'approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── School Stats Screen (dashboard banner tap) ────────────────────────────────

class _PrincipalSchoolStatsScreen extends StatelessWidget {
  const _PrincipalSchoolStatsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Statistics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: SchoolDataStore.instance,
        builder: (context, _) {
          final store = SchoolDataStore.instance;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildStatCard(
                context,
                label: 'Total Classes',
                value: '${store.classCount}',
                icon: Icons.class_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                context,
                label: 'Total Teachers',
                value: '${store.teacherCount}',
                icon: Icons.person_rounded,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                context,
                label: 'Total Students',
                value: '${store.studentCount}',
                icon: Icons.school_rounded,
                color: Colors.indigo,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                context,
                label: 'Total Staff',
                value: '${store.staffCount}',
                icon: Icons.badge_rounded,
                color: Colors.orange,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required String label,
      required String value,
      required IconData icon,
      required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTypography.headlineMedium
                        .copyWith(color: color, fontWeight: FontWeight.bold)),
                Text(label, style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── School Analytics Screen ───────────────────────────────────────────────────

class SchoolAnalyticsScreen extends StatelessWidget {
  const SchoolAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Analytics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('School analytics coming soon.',
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

// ── Student Progress Screen ───────────────────────────────────────────────────

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Progress'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Student progress coming soon.',
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

// ── Proof Approval Screen ─────────────────────────────────────────────────────

class ProofApprovalScreen extends StatelessWidget {
  const ProofApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof Approval'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Proof approval coming soon.',
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

// ── Proof Preview Screen ──────────────────────────────────────────────────────

class ProofPreviewScreen extends StatelessWidget {
  final String orderId;
  const ProofPreviewScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof Preview'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text('Proof preview for order $orderId.',
            style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}

// ── Order Progress Screen ─────────────────────────────────────────────────────

class OrderProgressScreen extends StatelessWidget {
  const OrderProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Progress'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Order progress coming soon.',
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
