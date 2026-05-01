import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/user_profile_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// USER PROFILE — delegates to the shared real-data profile screen
// ═══════════════════════════════════════════════════════════════════
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const SharedUserProfileScreen();
}

// ═══════════════════════════════════════════════════════════════════
// EDIT PROFILE — delegates to the shared real-data edit screen
// ═══════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  @override
  Widget build(BuildContext context) {
    // Load cached user then open shared edit screen
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.instance.getStoredUser(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return SharedEditProfileScreen(user: snap.data ?? {});
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SETTINGS
// ═══════════════════════════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsSection('Account', [
            _SettingsTile(
                Icons.person_rounded,
                'Profile',
                'View and edit your profile',
                () => context.go('/settings/profile')),
            _SettingsTile(Icons.security_rounded, 'Security',
                'Change password, 2FA', () {}),
          ]),
          const SizedBox(height: 16),
          _SettingsSection('Preferences', [
            _SettingsTile(Icons.palette_rounded, 'Theme', 'Light / Dark mode',
                () => context.go('/settings/theme')),
            _SettingsTile(
                Icons.notifications_rounded,
                'Notifications',
                'Manage alerts & alerts',
                () => context.go('/settings/notifications')),
            _SettingsTile(Icons.language_rounded, 'Language', 'English', () {}),
          ]),
          const SizedBox(height: 16),
          _SettingsSection('Support', [
            _SettingsTile(Icons.help_rounded, 'Help & Support',
                'Get assistance', () => context.go('/settings/help')),
            _SettingsTile(
                Icons.quiz_rounded,
                'FAQ',
                'Frequently asked questions',
                () => context.go('/settings/faq')),
            _SettingsTile(Icons.info_rounded, 'About', 'App version and info',
                () => context.go('/settings/about')),
          ]),
          const SizedBox(height: 16),
          PremiumCard(
            onTap: () => _showLogout(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                ),
                const SizedBox(width: 14),
                Text('Log Out',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log Out?'),
        content: const Text('You will be signed out of your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

Widget _SettingsSection(String title, List<Widget> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(), style: AppTypography.overline),
      ),
      PremiumCard(
        padding: EdgeInsets.zero,
        child: Column(children: items),
      ),
    ],
  );
}

Widget _SettingsTile(
    IconData icon, String title, String subtitle, VoidCallback onTap) {
  return Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTypography.labelMedium),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// THEME SETTINGS
// ═══════════════════════════════════════════════════════════════════
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _theme = 'system';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: AppTypography.titleSmall),
            const SizedBox(height: 16),
            ...[
              (
                'system',
                Icons.settings_brightness_rounded,
                'System Default',
                'Follow device setting'
              ),
              (
                'light',
                Icons.light_mode_rounded,
                'Light Mode',
                'Always use light theme'
              ),
              (
                'dark',
                Icons.dark_mode_rounded,
                'Dark Mode',
                'Always use dark theme'
              ),
            ].map((t) => PremiumCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () => setState(() => _theme = t.$1),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(t.$2, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.$3, style: AppTypography.labelMedium),
                            Text(t.$4, style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value: t.$1,
                        groupValue: _theme,
                        onChanged: (v) => setState(() => _theme = v!),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION SETTINGS
// ═══════════════════════════════════════════════════════════════════
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Map<String, bool> _prefs = {
    'Order Updates': true,
    'Proof Approvals': true,
    'Data Errors': true,
    'Payment Alerts': true,
    'Delivery Updates': false,
    'System Announcements': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: _prefs.entries.map<Widget>((e) {
          return PremiumCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: Text(e.key, style: AppTypography.labelMedium)),
                Switch(
                  value: e.value,
                  onChanged: (v) => setState(() => _prefs[e.key] = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELP & SUPPORT
// ═══════════════════════════════════════════════════════════════════
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GradientCard(
            gradient: AppColors.primaryGradient,
            child: Column(
              children: [
                const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text('How can we help?',
                    style: AppTypography.titleMedium
                        .copyWith(color: Colors.white)),
                Text('Our support team is available 24×7',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    )),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 24),
          ...[
            (
              Icons.chat_rounded,
              'Live Chat',
              'Chat with support agent',
              AppColors.primary
            ),
            (
              Icons.email_rounded,
              'Email Support',
              'support@edumid.app',
              AppColors.secondary
            ),
            (
              Icons.phone_rounded,
              'Call Support',
              '+91 1800-123-4567',
              AppColors.success
            ),
            (
              Icons.quiz_rounded,
              'FAQ',
              'Browse common questions',
              AppColors.accent
            ),
          ].map((s) => PremiumCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: s.$4.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.$1, color: s.$4, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$2, style: AppTypography.labelMedium),
                          Text(s.$3, style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FAQ
// ═══════════════════════════════════════════════════════════════════
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      (
        'How do I upload student data?',
        'Go to Vendor Hub → Upload Excel, then follow the column mapping wizard.'
      ),
      (
        'What photo formats are accepted?',
        'JPG and PNG formats are accepted. Minimum resolution is 200×200px.'
      ),
      (
        'How long does printing take?',
        'Typically 3–5 business days depending on quantity.'
      ),
      (
        'Can I edit student data after uploading?',
        'Yes, go to the student profile or use the Data Operator module to edit.'
      ),
      (
        'How is delivery tracked?',
        'Once dispatched, a tracking ID is shared via notifications and visible in the order details.'
      ),
      (
        'Who approves proofs?',
        'The School Principal reviews and approves/rejects design proofs.'
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          return ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            collapsedShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.5),
            collapsedBackgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.5),
            title: Text(faqs[i].$1, style: AppTypography.labelMedium),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(faqs[i].$2, style: AppTypography.bodyMedium),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABOUT
// ═══════════════════════════════════════════════════════════════════
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About EDUMID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 48),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text('EDUMID',
                style: AppTypography.displaySmall
                    .copyWith(color: AppColors.primary)),
            Text('Variable Data Printing Platform',
                style: AppTypography.bodyMedium),
            const SizedBox(height: 8),
            RoleBadge(label: 'Version 1.0.0', color: AppColors.primary),
            const SizedBox(height: 32),
            PremiumCard(
              child: Column(
                children: [
                  ...[
                    ('Version', '1.0.0'),
                    ('Build', '2025.03.01'),
                    ('Platform', 'Android'),
                    ('Developer', 'EDUMID Technologies'),
                    ('Contact', 'hello@edumid.app'),
                  ].map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
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
          ],
        ),
      ),
    );
  }
}
