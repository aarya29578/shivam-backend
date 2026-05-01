import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

/// Student sub-screens – zoom, download, share, QR verify, vCard, notifications

// ───────────────────────────────────────────────
// ID Card Zoom
// ───────────────────────────────────────────────
class IdCardZoomScreen extends StatelessWidget {
  const IdCardZoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Zoom View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => context.go('/student/id-card/share'),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5.0,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            height: 300,
            child: const Center(
              child: Icon(Icons.badge_rounded, size: 80, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
// Download PDF
// ───────────────────────────────────────────────
class DownloadPdfScreen extends StatefulWidget {
  const DownloadPdfScreen({super.key});

  @override
  State<DownloadPdfScreen> createState() => _DownloadPdfScreenState();
}

class _DownloadPdfScreenState extends State<DownloadPdfScreen> {
  double _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _simulate();
  }

  Future<void> _simulate() async {
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _progress = i / 10);
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download PDF'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _done
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _done
                      ? Icons.check_circle_rounded
                      : Icons.picture_as_pdf_rounded,
                  size: 44,
                  color: _done ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _done ? 'Download Complete!' : 'Preparing PDF...',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _done
                    ? 'Your ID card PDF has been saved to Downloads'
                    : 'Generating high-quality ID card PDF',
                style: AppTypography.bodyMedium.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!_done) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ] else ...[
                PrimaryButton(
                  label: 'Open File',
                  onTap: () {},
                  prefixIcon: Icons.open_in_new_rounded,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to ID Card'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
// Share ID Card
// ───────────────────────────────────────────────
class ShareIdCardScreen extends StatelessWidget {
  const ShareIdCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      _ShareOption(
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          color: const Color(0xFF25D366)),
      _ShareOption(
          icon: Icons.send_rounded,
          label: 'Telegram',
          color: const Color(0xFF0088CC)),
      _ShareOption(
          icon: Icons.mail_rounded, label: 'Email', color: AppColors.accent),
      _ShareOption(
          icon: Icons.copy_rounded,
          label: 'Copy Link',
          color: AppColors.primary),
      _ShareOption(
          icon: Icons.save_alt_rounded,
          label: 'Save Image',
          color: AppColors.success),
      _ShareOption(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          color: AppColors.textSecondaryLight),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Share ID Card')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.badge_rounded, size: 64, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text('Share via', style: AppTypography.titleSmall),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: options
                  .map(
                    (opt) => GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sharing via ${opt.label}...'),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: opt.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: opt.color.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(opt.icon, color: opt.color, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              opt.label,
                              style: AppTypography.labelSmall
                                  .copyWith(color: opt.color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption {
  final IconData icon;
  final String label;
  final Color color;
  const _ShareOption(
      {required this.icon, required this.label, required this.color});
}

// ───────────────────────────────────────────────
// Digital vCard
// ───────────────────────────────────────────────
class DigitalVcardScreen extends StatelessWidget {
  const DigitalVcardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital vCard')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // vCard preview
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.secondaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const AppAvatar(name: 'Arjun Sharma', size: 80),
                  const SizedBox(height: 16),
                  Text(
                    'Arjun Sharma',
                    style:
                        AppTypography.titleLarge.copyWith(color: Colors.white),
                  ),
                  Text(
                    'Student | Class X-A',
                    style: AppTypography.bodyMedium
                        .copyWith(color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  _VCardRow(
                      icon: Icons.school_rounded, text: 'Delhi Public School'),
                  _VCardRow(icon: Icons.phone_rounded, text: '+91 98765 43210'),
                  _VCardRow(
                      icon: Icons.location_on_rounded,
                      text: 'New Delhi, India'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Action buttons
            PrimaryButton(
              label: 'Save Contact',
              onTap: () {},
              prefixIcon: Icons.person_add_rounded,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              icon: const Icon(Icons.qr_code_rounded, size: 18),
              label: const Text('Show QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VCardRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _VCardRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
          const SizedBox(width: 10),
          Text(
            text,
            style: AppTypography.bodySmall
                .copyWith(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// QR Verification
// ───────────────────────────────────────────────
class QrVerificationScreen extends StatefulWidget {
  const QrVerificationScreen({super.key});

  @override
  State<QrVerificationScreen> createState() => _QrVerificationScreenState();
}

class _QrVerificationScreenState extends State<QrVerificationScreen> {
  bool _verified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              'Show this QR code for identity verification',
              style: AppTypography.bodyMedium.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // QR Code
            GestureDetector(
              onTap: () => setState(() => _verified = !_verified),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        _verified ? AppColors.success : AppColors.borderLight,
                    width: _verified ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_verified ? AppColors.success : AppColors.primary)
                          .withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 180,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_verified)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Identity Verified!',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student Details', style: AppTypography.labelLarge),
                  const SizedBox(height: 12),
                  _DetailRow('Name', 'Arjun Sharma'),
                  _DetailRow('Roll No.', '23'),
                  _DetailRow('Class', 'X - A'),
                  _DetailRow('School', 'Delhi Public School'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          Text(value, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// Student Notifications
// ───────────────────────────────────────────────
class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NotifItem(
        icon: Icons.badge_rounded,
        title: 'ID Card Ready',
        body: 'Your ID card has been generated. Tap to view.',
        time: '2h ago',
        color: AppColors.primary,
        isRead: false,
      ),
      _NotifItem(
        icon: Icons.check_circle_rounded,
        title: 'Data Verified',
        body: 'Your student data has been verified by the teacher.',
        time: 'Yesterday',
        color: AppColors.success,
        isRead: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return PremiumCard(
            onTap: () {},
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                      Row(
                        children: [
                          Expanded(
                              child: Text(item.title,
                                  style: AppTypography.labelLarge)),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final Color color;
  final bool isRead;
  const _NotifItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.color,
    required this.isRead,
  });
}
