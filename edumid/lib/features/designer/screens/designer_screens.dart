import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/logout_helper.dart';

// ═══════════════════════════════════════════════════════════════════
// DESIGNER DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class DesignerDashboardScreen extends StatelessWidget {
  const DesignerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: AppColors.roleDesigner,
            foregroundColor: Colors.white,
            title: const Text('Designer Studio'),
            actions: const [LogoutActionButton()],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.roleDesigner, AppColors.rolePrincipal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, Designer',
                            style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.7))),
                        Text('Your Creative Studio',
                            style: AppTypography.headlineMedium
                                .copyWith(color: Colors.white)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _DStat('Assigned', '6'),
                            const SizedBox(width: 8),
                            _DStat('Submitted', '14'),
                            const SizedBox(width: 8),
                            _DStat('Approved', '42'),
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
                SectionHeader(
                  title: 'Pending Tasks',
                  action: 'All',
                  onAction: () => context.go('/designer/projects'),
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  3,
                  (i) => PremiumCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => context.go('/designer/preview/T00$i'),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: i.isEven
                                ? AppColors.primaryGradient
                                : AppColors.secondaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.badge_rounded,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('School ${i + 1} – Batch 2025',
                                  style: AppTypography.labelLarge),
                              Text('Due: Mar ${10 + i * 2}, 2025',
                                  style: AppTypography.bodySmall),
                              const SizedBox(height: 6),
                              RoleBadge(
                                label: [
                                  'In Progress',
                                  'Not Started',
                                  'Review'
                                ][i],
                                color: [
                                  AppColors.primary,
                                  AppColors.warning,
                                  AppColors.accent
                                ][i],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ).toList(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DStat extends StatelessWidget {
  final String label;
  final String value;
  const _DStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTypography.titleSmall.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ASSIGNED PROJECTS
// ═══════════════════════════════════════════════════════════════════
class AssignedProjectsScreen extends StatelessWidget {
  const AssignedProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assigned Projects')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          return PremiumCard(
            onTap: () => context.go('/designer/preview/P00$i'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('School ${i + 1} – Batch 2025',
                        style: AppTypography.labelLarge),
                    RoleBadge(
                      label: i < 2
                          ? 'Pending'
                          : i < 4
                              ? 'In Progress'
                              : 'Review',
                      color: i < 2
                          ? AppColors.warning
                          : i < 4
                              ? AppColors.primary
                              : AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${800 + i * 150} student cards',
                    style: AppTypography.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text('Due: Mar ${10 + i * 2}, 2025',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warning,
                        )),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TEMPLATE PREVIEW (SELECTOR)
// ═══════════════════════════════════════════════════════════════════
class TemplatePreviewScreen extends StatefulWidget {
  final String projectId;
  const TemplatePreviewScreen({super.key, required this.projectId});

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Templates – ${widget.projectId}'),
        actions: [
          TextButton(
            onPressed: () =>
                context.go('/designer/id-card-preview/${widget.projectId}'),
            child: const Text('Next'),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.65,
        ),
        itemCount: 6,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selected == i
                      ? AppColors.roleDesigner
                      : Colors.transparent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _selected == i
                    ? [
                        BoxShadow(
                          color: AppColors.roleDesigner.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        [AppColors.primary, AppColors.secondary],
                        [AppColors.secondary, AppColors.roleDesigner],
                        [AppColors.accent, AppColors.primary],
                        [AppColors.roleTeacher, AppColors.rolePrincipal],
                        [AppColors.roleVendor, AppColors.primary],
                        [AppColors.secondary, AppColors.accent],
                      ][i],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 8),
                        Text('STUDENT NAME',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                            )),
                        Text('Class X-A | Roll 1001',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            )),
                        const SizedBox(height: 8),
                        Text('Template ${i + 1}',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.5),
                            )),
                        if (_selected == i) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Selected',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                )),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ID CARD PREVIEW (DESIGNER)
// ═══════════════════════════════════════════════════════════════════
class IdCardPreviewDesignerScreen extends StatelessWidget {
  final String projectId;
  const IdCardPreviewDesignerScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview – $projectId'),
        actions: [
          TextButton(
            onPressed: () => context.go('/designer/generate-proof/$projectId'),
            child: const Text('Generate Proof'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Container(
                  width: 280,
                  height: 420,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4), width: 2),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text('AARAV SHARMA',
                            style: AppTypography.titleMedium
                                .copyWith(color: Colors.white)),
                        Text('Class X-A | Roll #1001',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            )),
                        const SizedBox(height: 20),
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text('Delhi Public School',
                            style: AppTypography.labelMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _DesignerNavigator(projectId: projectId),
        ],
      ),
    );
  }
}

class _DesignerNavigator extends StatefulWidget {
  final String projectId;
  const _DesignerNavigator({required this.projectId});

  @override
  State<_DesignerNavigator> createState() => _DesignerNavigatorState();
}

class _DesignerNavigatorState extends State<_DesignerNavigator> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _index > 0 ? () => setState(() => _index--) : null,
          ),
          Expanded(
            child: Text('Student ${_index + 1} of 1,248',
                style: AppTypography.labelMedium, textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() => _index++),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GENERATE PROOF
// ═══════════════════════════════════════════════════════════════════
class GenerateProofScreen extends StatefulWidget {
  final String projectId;
  const GenerateProofScreen({super.key, required this.projectId});

  @override
  State<GenerateProofScreen> createState() => _GenerateProofScreenState();
}

class _GenerateProofScreenState extends State<GenerateProofScreen> {
  bool _generating = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Proof')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proof Summary', style: AppTypography.titleSmall),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                children: [
                  _ProofRow('Project', 'School 1 – Batch 2025'),
                  _ProofRow('Template', 'Template 1 (Blue Gradient)'),
                  _ProofRow('Total Cards', '1,248'),
                  _ProofRow('Sample Size', '5 cards (for review)'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_generating || _progress > 0) ...[
              Text(
                _generating ? 'Generating proof...' : 'Proof ready!',
                style: AppTypography.labelLarge.copyWith(
                  color: _generating ? AppColors.primary : AppColors.success,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  color: _generating ? AppColors.primary : AppColors.success,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Spacer(),
            GradientButton(
              label:
                  _progress == 1.0 ? 'Submit for Approval' : 'Generate Proof',
              loading: _generating,
              onPressed: () async {
                if (_progress == 1.0) {
                  context.go('/designer/submit-proof/${widget.projectId}');
                } else {
                  setState(() => _generating = true);
                  for (int i = 1; i <= 10; i++) {
                    await Future.delayed(const Duration(milliseconds: 200));
                    setState(() => _progress = i / 10);
                  }
                  setState(() => _generating = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProofRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              )),
          Text(value, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SUBMIT PROOF
// ═══════════════════════════════════════════════════════════════════
class SubmitProofScreen extends StatefulWidget {
  final String projectId;
  const SubmitProofScreen({super.key, required this.projectId});

  @override
  State<SubmitProofScreen> createState() => _SubmitProofScreenState();
}

class _SubmitProofScreenState extends State<SubmitProofScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Proof')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submission Notes', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            const AppTextField(
              label: 'Notes for reviewer',
              hint: 'Any special instructions or changes made...',
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.error, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('proof_school1_batch2025.pdf',
                            style: AppTypography.labelMedium),
                        Text('4.2 MB', style: AppTypography.bodySmall),
                      ],
                    ),
                  ]),
                ],
              ),
            ),
            const Spacer(),
            GradientButton(
              label: 'Submit for Approval',
              loading: _loading,
              onPressed: () async {
                setState(() => _loading = true);
                await Future.delayed(const Duration(seconds: 1));
                if (context.mounted) {
                  context.go('/designer/proof-success');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROOF SUCCESS
// ═══════════════════════════════════════════════════════════════════
class ProofSuccessScreen extends StatelessWidget {
  const ProofSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 48),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text('Proof Submitted!', style: AppTypography.headlineMedium)
                  .animate()
                  .fadeIn(delay: 400.ms),
              const SizedBox(height: 12),
              Text(
                'Your proof has been sent for principal approval. You\'ll be notified once reviewed.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 40),
              GradientButton(
                label: 'Back to Projects',
                onPressed: () => context.go('/designer/projects'),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}
