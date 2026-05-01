import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/id_card_form_fill_screen.dart';
import '../../../core/services/auth_service.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final stored = await AuthService.instance.getStoredUser();
      if (stored != null && mounted) {
        setState(() => _user = stored);
      }
      // Refresh from server in background
      final fresh = await AuthService.instance.getProfile();
      if (fresh != null && mounted) {
        setState(() => _user = fresh);
      }
    } catch (_) {}
  }

  String get _displayName => (_user?['name'] as String? ?? 'Student').trim();
  String get _displayInitials {
    final parts = _displayName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'S';
  }

  String get _classRollLabel {
    final cls = (_user?['className'] as String? ?? '').trim();
    final roll = (_user?['rollNumber'] as String? ?? '').trim();
    if (cls.isNotEmpty && roll.isNotEmpty) return 'Class $cls  |  Roll $roll';
    if (cls.isNotEmpty) return 'Class $cls';
    if (roll.isNotEmpty) return 'Roll $roll';
    return '';
  }

  String get _profileImage => (_user?['profileImage'] as String? ?? '').trim();

  Widget _initialsAvatar() => CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary,
        child: Text(
          _displayInitials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Header (sized to content)
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white70, width: 1),
                            ),
                            child: ClipOval(
                              child: _profileImage.isNotEmpty
                                  ? Image.network(
                                      '${ApiConfig.resolveImageUrl(_profileImage)}?t=${DateTime.now().millisecondsSinceEpoch}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _initialsAvatar(),
                                    )
                                  : _initialsAvatar(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _displayName,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_classRollLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _classRollLabel,
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                            ),
                            tooltip: 'Share App',
                            onPressed: () => Share.share(
                              'EduMid – India\'s #1 School ID Card App 🎓\nInstall now: https://edumid.app',
                              subject: 'Check out EduMid App!',
                            ),
                          ),
                          NotificationBadge(
                            count: 3,
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  context.go('/student/notifications'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ID Card preview
                SectionHeader(
                  title: 'My ID Card',
                  action: 'View Full',
                  onAction: () => context.go('/student/id-card'),
                ),
                const SizedBox(height: 12),
                const _FlippableIdCard(),
                const SizedBox(height: 20),

                // Quick actions grid
                _buildQuickActions(context),
                const SizedBox(height: 20),

                // Recent activity
                SectionHeader(
                  title: 'Recent Activity',
                  action: 'See All',
                  onAction: () => context.go('/notifications'),
                ),
                const SizedBox(height: 12),
                ..._buildActivityItems(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _Action(
        icon: Icons.badge_rounded,
        label: 'ID Card',
        color: AppColors.primary,
        route: '/student/id-card',
      ),
      _Action(
        icon: Icons.qr_code_2_rounded,
        label: 'QR Verify',
        color: AppColors.secondary,
        route: '/student/qr-verify',
      ),
      _Action(
        icon: Icons.download_rounded,
        label: 'Download',
        color: AppColors.success,
        route: '/student/id-card/download',
      ),
      _Action(
        icon: Icons.edit_note,
        label: 'Correction',
        color: AppColors.accent,
        route: '/student/correction-request',
      ),
      _Action(
        icon: Icons.print_rounded,
        label: 'Lost &\nReprint',
        color: AppColors.primary,
        route: '/student/reprint-request',
      ),
      _Action(
        icon: Icons.card_travel_rounded,
        label: 'Form',
        color: const Color(0xFF6D28D9),
        route: '/student/form',
        onTap: () async {
          final user = await AuthService.instance.getStoredUser();
          if (!context.mounted) return;

          final principalId = (user?['principalId'] ?? '').toString().trim();
          if (principalId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('School mapping not found. Please login again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          final userId = (user?['id'] ?? '').toString();
          final userPhone = (user?['phone'] ?? '').toString();
          final userName = (user?['name'] ?? 'Student').toString();

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IdCardFormFillScreen(
                principalId: principalId,
                userId: userId,
                userEmail: userPhone,
                userName: userName,
                role: 'student',
              ),
            ),
          );
        },
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: actions
          .asMap()
          .entries
          .map(
            (e) => GestureDetector(
              onTap: () {
                if (e.value.onTap != null) {
                  e.value.onTap!();
                } else {
                  context.go(e.value.route);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: e.value.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      e.value.icon,
                      color: e.value.color,
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.value.label,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ).animate().fadeIn(
                    delay: Duration(milliseconds: 100 * e.key),
                    duration: 400.ms,
                  ),
            ),
          )
          .toList(),
    );
  }

  // _buildIdCardPreview replaced by _FlippableIdCard widget below

  List<Widget> _buildActivityItems(BuildContext context) {
    final items = [
      _ActivityItem(
        icon: Icons.badge_rounded,
        title: 'ID Card Generated',
        subtitle: 'Your ID card is ready to download',
        time: '2 hours ago',
        color: AppColors.primary,
      ),
      _ActivityItem(
        icon: Icons.download_done_rounded,
        title: 'PDF Downloaded',
        subtitle: 'ID card PDF saved to device',
        time: 'Yesterday',
        color: AppColors.success,
      ),
    ];

    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              onTap: () => context.go('/notifications'),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AppTypography.labelLarge),
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
                  Text(
                    item.time,
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flippable ID Card
// ─────────────────────────────────────────────────────────────────────────────

class _FlippableIdCard extends StatefulWidget {
  const _FlippableIdCard();

  @override
  State<_FlippableIdCard> createState() => _FlippableIdCardState();
}

class _FlippableIdCardState extends State<_FlippableIdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_ctrl.isAnimating) return;
    _ctrl.isDismissed ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final v = _ctrl.value;
          final isFront = v <= 0.5;
          // Front tilts from 0 → π/2; back comes in from -π/2 → 0.
          final angle = isFront ? v * pi : (v - 1) * pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront ? const _IdCardFront() : const _IdCardBack(),
          );
        },
      ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
    );
  }
}

class _IdCardFront extends StatelessWidget {
  const _IdCardFront();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DELHI PUBLIC SCHOOL',
                        style: AppTypography.overline.copyWith(
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ARJUN SHARMA',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _InfoRow(label: 'Class', value: 'X - A'),
                      const SizedBox(height: 4),
                      const _InfoRow(label: 'Roll No.', value: '23'),
                      const SizedBox(height: 4),
                      const _InfoRow(label: 'DOB', value: '15 Jan 2008'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            right: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flip_rounded,
                    size: 12, color: Colors.white.withOpacity(0.45)),
                const SizedBox(width: 4),
                Text(
                  'Tap to flip',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.45),
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

class _IdCardBack extends StatelessWidget {
  const _IdCardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STUDENT DETAILS',
                        style: AppTypography.overline.copyWith(
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _InfoRow(label: 'Blood Grp', value: 'B+'),
                      const SizedBox(height: 4),
                      const _InfoRow(label: 'Phone', value: '+91 98765 43210'),
                      const SizedBox(height: 4),
                      const _InfoRow(
                          label: 'Address', value: '123 School Lane'),
                      const SizedBox(height: 4),
                      const _InfoRow(
                          label: 'Emergency', value: '+91 98765 00000'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 72,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_rounded,
                          color: Colors.white.withOpacity(0.9), size: 44),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to\nverify',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            right: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flip_rounded,
                    size: 12, color: Colors.white.withOpacity(0.45)),
                const SizedBox(width: 4),
                Text(
                  'Tap to flip',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.45),
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

// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: Colors.white.withOpacity(0.65),
          ),
        ),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final VoidCallback? onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.onTap,
  });
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}
