import 'package:flutter/material.dart';

import '../../core/api/api_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/app_widgets.dart';
import '../widgets/logout_helper.dart';

// ═══════════════════════════════════════════════════════════════════
// SHARED USER PROFILE SCREEN
// Used by student, teacher, principal, and vendor roles.
// Fetches real data from backend via /api/auth/profile.
// ═══════════════════════════════════════════════════════════════════

class SharedUserProfileScreen extends StatefulWidget {
  const SharedUserProfileScreen({super.key});

  @override
  State<SharedUserProfileScreen> createState() =>
      _SharedUserProfileScreenState();
}

class _SharedUserProfileScreenState extends State<SharedUserProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // First show cached data quickly, then refresh from backend.
    final cached = await AuthService.instance.getStoredUser();
    if (mounted && cached != null)
      setState(() {
        _user = cached;
        _loading = false;
      });

    final fresh = await AuthService.instance.getProfile();
    if (mounted && fresh != null)
      setState(() {
        _user = fresh;
        _loading = false;
      });
    if (mounted) setState(() => _loading = false);
  }

  String get _name => (_user?['name'] ?? '').toString();
  String get _phone => (_user?['phone'] ?? '').toString();
  String get _role => (_user?['role'] ?? '').toString();
  String get _schoolCode => (_user?['schoolCode'] ?? '').toString();
  String get _schoolName => (_user?['schoolName'] ?? '').toString();
  String get _profileImage => (_user?['profileImage'] ?? '').toString().trim();
  String get _className => (_user?['className'] ?? '').toString().trim();
  String get _rollNumber => (_user?['rollNumber'] ?? '').toString().trim();

  Color get _roleColor {
    switch (_role) {
      case 'teacher':
        return const Color(0xFF7C3AED);
      case 'principal':
        return const Color(0xFF0F766E);
      case 'vendor':
        return const Color(0xFF1D4ED8);
      default:
        return AppColors.primary;
    }
  }

  String get _roleLabel {
    if (_role.isEmpty) return '';
    return _role[0].toUpperCase() + _role.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading && _user == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: _roleColor,
                  foregroundColor: Colors.white,
                  title: const Text('My Profile'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: 'Edit Profile',
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                SharedEditProfileScreen(user: _user ?? {}),
                          ),
                        );
                        if (updated == true) _loadProfile();
                      },
                    ),
                    const LogoutActionButton(),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_roleColor, _roleColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _profileImage.isNotEmpty
                                ? CircleAvatar(
                                    radius: 40,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.3),
                                    backgroundImage: NetworkImage(
                                        '${ApiConfig.resolveImageUrl(_profileImage)}?t=${DateTime.now().millisecondsSinceEpoch}'),
                                    onBackgroundImageError: (_, __) {},
                                  )
                                : AppAvatar(
                                    name: _name.isNotEmpty ? _name : '?',
                                    radius: 40),
                            const SizedBox(height: 12),
                            Text(
                              _name.isNotEmpty ? _name : '—',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_schoolName.isNotEmpty)
                              Text(
                                _schoolName,
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.35)),
                              ),
                              child: Text(
                                _roleLabel,
                                style: AppTypography.labelSmall
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Body ────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle('Account Info', Icons.person_rounded,
                                _roleColor),
                            const SizedBox(height: 12),
                            _InfoRow(Icons.badge_rounded, 'Name',
                                _name.isNotEmpty ? _name : '—', _roleColor),
                            const Divider(height: 20),
                            _InfoRow(Icons.phone_rounded, 'Phone',
                                _phone.isNotEmpty ? _phone : '—', _roleColor),
                            const Divider(height: 20),
                            _InfoRow(
                                Icons.manage_accounts_rounded,
                                'Role',
                                _roleLabel.isNotEmpty ? _roleLabel : '—',
                                _roleColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle('School Info', Icons.school_rounded,
                                _roleColor),
                            const SizedBox(height: 12),
                            _InfoRow(
                                Icons.domain_rounded,
                                'School Name',
                                _schoolName.isNotEmpty ? _schoolName : '—',
                                _roleColor),
                            const Divider(height: 20),
                            _InfoRow(
                                Icons.numbers_rounded,
                                'School Code',
                                _schoolCode.isNotEmpty ? _schoolCode : '—',
                                _roleColor),
                            if (_role == 'student') ...[
                              const Divider(height: 20),
                              _InfoRow(
                                  Icons.class_rounded,
                                  'Class',
                                  _className.isNotEmpty ? _className : '—',
                                  _roleColor),
                              const Divider(height: 20),
                              _InfoRow(
                                  Icons.format_list_numbered_rounded,
                                  'Roll No',
                                  _rollNumber.isNotEmpty ? _rollNumber : '—',
                                  _roleColor),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Small helpers ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.labelLarge.copyWith(color: color)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.labelSmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  )),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EDIT PROFILE SCREEN (shared)
// ═══════════════════════════════════════════════════════════════════

class SharedEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SharedEditProfileScreen({super.key, required this.user});

  @override
  State<SharedEditProfileScreen> createState() =>
      _SharedEditProfileScreenState();
}

class _SharedEditProfileScreenState extends State<SharedEditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: (widget.user['name'] ?? '').toString());
    _phoneCtrl =
        TextEditingController(text: (widget.user['phone'] ?? '').toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to update')),
      );
      return;
    }
    setState(() => _loading = true);
    final error = await AuthService.instance.updateProfile(
      name: name.isEmpty ? null : name,
      phone: phone.isEmpty ? null : phone,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true); // signals caller to refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final role = (user['role'] ?? '').toString();
    final schoolCode = (user['schoolCode'] ?? '').toString();
    final schoolName = (user['schoolName'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: AppAvatar(
                    name: (widget.user['name'] ?? '?').toString(), radius: 44)),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Full Name',
              controller: _nameCtrl,
              hint: 'Your name',
              validator: (v) => null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Phone Number',
              controller: _phoneCtrl,
              hint: 'Your phone',
              keyboardType: TextInputType.phone,
              validator: (v) => null,
            ),
            const SizedBox(height: 20),
            // Read-only fields
            _ReadOnlyField(
                label: 'Role',
                value: role.isNotEmpty
                    ? role[0].toUpperCase() + role.substring(1)
                    : '—'),
            const SizedBox(height: 10),
            _ReadOnlyField(
                label: 'School Code',
                value: schoolCode.isNotEmpty ? schoolCode : '—'),
            const SizedBox(height: 10),
            _ReadOnlyField(
                label: 'School Name',
                value: schoolName.isNotEmpty ? schoolName : '—'),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Save Changes',
              onTap: _save,
              isLoading: _loading,
              prefixIcon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            )),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(value,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              )),
        ),
      ],
    );
  }
}
