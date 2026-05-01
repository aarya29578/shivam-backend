import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/logout_helper.dart';

// ═══════════════════════════════════════════════════════════════════
// OPERATOR DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class OperatorDashboardScreen extends StatelessWidget {
  const OperatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.roleDataOperator,
            foregroundColor: Colors.white,
            title: const Text('Data Operations'),
            actions: const [LogoutActionButton()],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.roleDataOperator,
                      AppColors.primary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good morning,',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  )),
                              Text('Data Operator',
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: Colors.white,
                                  )),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Tasks Today',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                )),
                            Text('8',
                                style: AppTypography.displaySmall.copyWith(
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(
                        child: StatCard(
                            title: 'Pending',
                            value: '3',
                            icon: Icons.pending_actions_rounded,
                            color: AppColors.warning)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            title: 'Errors',
                            value: '12',
                            icon: Icons.error_rounded,
                            color: AppColors.error)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            title: 'Done',
                            value: '24',
                            icon: Icons.task_alt_rounded,
                            color: AppColors.success)),
                  ],
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),
                SectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                  children: [
                    _OPActionCard(
                        'Upload Excel',
                        Icons.upload_file_rounded,
                        AppColors.primary,
                        () => context.go('/operator/excel-upload')),
                    _OPActionCard(
                        'Validate',
                        Icons.fact_check_rounded,
                        AppColors.secondary,
                        () => context.go('/operator/data-validation')),
                    _OPActionCard(
                        'Duplicates',
                        Icons.copy_rounded,
                        AppColors.warning,
                        () => context.go('/operator/duplicate-detection')),
                    _OPActionCard(
                        'Fix Errors',
                        Icons.build_circle_rounded,
                        AppColors.error,
                        () => context.go('/operator/error-correction')),
                    _OPActionCard(
                        'Photos',
                        Icons.photo_library_rounded,
                        AppColors.roleDesigner,
                        () => context.go('/operator/photo-matching')),
                    _OPActionCard(
                        'Bulk Rename',
                        Icons.drive_file_rename_outline_rounded,
                        AppColors.accent,
                        () => context.go('/operator/bulk-rename')),
                  ],
                ).animate().fadeIn(delay: 300.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _OPActionCard(
        String label, IconData icon, Color color, VoidCallback onTap) =>
    PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );

// ═══════════════════════════════════════════════════════════════════
// EXCEL UPLOAD (OPERATOR)
// ═══════════════════════════════════════════════════════════════════
class ExcelUploadScreen extends StatefulWidget {
  const ExcelUploadScreen({super.key});

  @override
  State<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends State<ExcelUploadScreen> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Excel Upload')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selected = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selected
                        ? AppColors.success
                        : AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: _selected
                      ? AppColors.success.withOpacity(0.05)
                      : AppColors.primary.withOpacity(0.04),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selected
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 54,
                      color: _selected ? AppColors.success : AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selected
                          ? 'data_batch2025.xlsx'
                          : 'Tap to upload Excel file',
                      style: AppTypography.labelMedium.copyWith(
                        color:
                            _selected ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    if (_selected)
                      Text('1,248 rows detected',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success.withOpacity(0.7))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_selected)
              GradientButton(
                label: 'Map Columns',
                onPressed: () => context.go('/operator/column-mapping'),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// COLUMN MAPPING (OPERATOR)
// ═══════════════════════════════════════════════════════════════════
class ColumnMappingOpScreen extends StatelessWidget {
  const ColumnMappingOpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const required = [
      'Student Name',
      'Class',
      'Roll No',
      'DOB',
      'Parent',
      'Phone'
    ];
    const excel = [
      'Name',
      'Class',
      'Roll',
      'Date of Birth',
      'Guardian',
      'Mobile'
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Map Columns')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: required.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => PremiumCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Required',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.primary)),
                          Text(required[i], style: AppTypography.labelMedium),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your File',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.secondary)),
                          Text(excel[i], style: AppTypography.labelMedium),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GradientButton(
              label: 'Validate Data',
              onPressed: () => context.go('/operator/data-validation'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA VALIDATION
// ═══════════════════════════════════════════════════════════════════
class DataValidationScreen extends StatelessWidget {
  const DataValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Validation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Validation Summary', style: AppTypography.titleSmall),
                  const SizedBox(height: 16),
                  _ValidationStat('Total Records', '1,248', AppColors.primary),
                  _ValidationStat('Valid', '1,186', AppColors.success),
                  _ValidationStat('Warnings', '38', AppColors.warning),
                  _ValidationStat('Errors', '24', AppColors.error),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(5, (i) {
              final isError = i < 2;
              return PremiumCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isError ? AppColors.error : AppColors.warning)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isError ? Icons.error_rounded : Icons.warning_rounded,
                        color: isError ? AppColors.error : AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Row ${1001 + i}: Invalid ${isError ? "DOB format" : "phone number"}',
                              style: AppTypography.labelMedium),
                          Text('Student: Aarav ${String.fromCharCode(65 + i)}',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/operator/error-correction'),
                      child: const Text('Fix'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ValidationStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ValidationStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium),
          Text(value, style: AppTypography.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DUPLICATE DETECTION
// ═══════════════════════════════════════════════════════════════════
class DuplicateDetectionScreen extends StatelessWidget {
  const DuplicateDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicate Detection')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.copy_rounded, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('6 duplicate entries found',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.warning)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                return PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Duplicate Group ${i + 1}',
                              style: AppTypography.labelLarge),
                          RoleBadge(
                              label: '2 entries', color: AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _DupCard('Row 1${12 + i}', 'Original')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _DupCard('Row 2${45 + i}', 'Duplicate')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Keep Original'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                              child: const Text('Delete Duplicate'),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _DupCard extends StatelessWidget {
  final String row;
  final String label;
  const _DupCard(this.row, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row, style: AppTypography.labelSmall),
          Text(label, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ERROR CORRECTION
// ═══════════════════════════════════════════════════════════════════
class ErrorCorrectionScreen extends StatelessWidget {
  const ErrorCorrectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error Correction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Row 1042 – Fix Errors', style: AppTypography.titleSmall),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text('Invalid Date of Birth',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const AppTextField(
                    label: 'Date of Birth',
                    hint: 'DD/MM/YYYY',
                    keyboardType: TextInputType.datetime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text('Invalid Phone Number',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const AppTextField(
                    label: 'Phone Number',
                    hint: '+91 XXXXX XXXXX',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Save Corrections',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Corrections saved!')),
                );
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PHOTO MATCHING (OPERATOR)
// ═══════════════════════════════════════════════════════════════════
class PhotoMatchingScreen extends StatelessWidget {
  const PhotoMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Matching')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PhotoMatchStat('Matched', '1,186', AppColors.success),
                _PhotoMatchStat('Unmatched', '62', AppColors.warning),
                _PhotoMatchStat('Missing', '0', AppColors.error),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 10,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final matched = i < 8;
                return PremiumCard(
                  onTap: !matched
                      ? () => context.go('/operator/photo-quality')
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 56,
                        decoration: BoxDecoration(
                          color: matched
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          matched
                              ? Icons.image_rounded
                              : Icons.broken_image_rounded,
                          color:
                              matched ? AppColors.primary : AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student ${1001 + i}',
                                style: AppTypography.labelMedium),
                            Text(
                              matched
                                  ? 'Photo matched'
                                  : 'Needs manual assignment',
                              style: AppTypography.bodySmall.copyWith(
                                color: matched
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!matched)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Assign',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.warning,
                              )),
                        ),
                    ],
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

class _PhotoMatchStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PhotoMatchStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.titleSmall.copyWith(color: color)),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PHOTO QUALITY CHECK
// ═══════════════════════════════════════════════════════════════════
class PhotoQualityScreen extends StatelessWidget {
  const PhotoQualityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Quality')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Photo preview
            Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.person_rounded, size: 80, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quality Checks', style: AppTypography.titleSmall),
                  const SizedBox(height: 12),
                  ...[
                    ('Resolution (200×200px min)', true),
                    ('Clear facial visibility', true),
                    ('No sunglasses/headwear', false),
                    ('Proper lighting', true),
                  ].map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(
                              r.$2
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: r.$2 ? AppColors.success : AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(r.$1, style: AppTypography.bodyMedium),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Replace'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BULK RENAME
// ═══════════════════════════════════════════════════════════════════
class BulkRenameScreen extends StatefulWidget {
  const BulkRenameScreen({super.key});

  @override
  State<BulkRenameScreen> createState() => _BulkRenameScreenState();
}

class _BulkRenameScreenState extends State<BulkRenameScreen> {
  String _pattern = '{roll_number}';
  bool _running = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Rename')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rename Pattern', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                '{roll_number}',
                '{name}',
                '{class}',
                '{section}',
              ].map((p) {
                return GestureDetector(
                  onTap: () => setState(() => _pattern = p),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _pattern == p
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p,
                      style: AppTypography.labelSmall.copyWith(
                        color: _pattern == p ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: AppTypography.labelMedium),
                  const SizedBox(height: 8),
                  Text('1001.jpg, 1002.jpg, 1003.jpg ...',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_running || _progress > 0) ...[
              Text(
                _running ? 'Renaming...' : 'Done! All files renamed.',
                style: AppTypography.labelMedium.copyWith(
                  color: _running ? AppColors.primary : AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                color: _running ? AppColors.primary : AppColors.success,
              ),
              const SizedBox(height: 16),
            ],
            const Spacer(),
            GradientButton(
              label: 'Run Rename',
              loading: _running,
              onPressed: () async {
                setState(() {
                  _running = true;
                  _progress = 0;
                });
                for (int i = 1; i <= 10; i++) {
                  await Future.delayed(const Duration(milliseconds: 200));
                  setState(() => _progress = i / 10);
                }
                setState(() => _running = false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
