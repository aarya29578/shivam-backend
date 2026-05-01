import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../corrections/corrections_repository.dart';
import '../../corrections/models/correction_request.dart';

class TeacherCorrectionDetailScreen extends StatefulWidget {
  final String requestId;
  const TeacherCorrectionDetailScreen({super.key, required this.requestId});

  @override
  State<TeacherCorrectionDetailScreen> createState() =>
      _TeacherCorrectionDetailScreenState();
}

class _TeacherCorrectionDetailScreenState
    extends State<TeacherCorrectionDetailScreen> {
  final _repo = CorrectionsRepository.instance;
  bool _isProcessing = false;

  Future<void> _handleAction(bool approve, {String? reason}) async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (approve) {
      _repo.approve(widget.requestId);
    } else {
      _repo.reject(widget.requestId, reason: reason);
    }
    setState(() => _isProcessing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Changes approved!' : 'Request rejected.'),
        backgroundColor: approve ? AppColors.success : AppColors.error,
      ));
      context.pop();
    }
  }

  void _share(CorrectionRequest req) {
    final changedFields = req.requestedChanges.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
    final statusLabel = req.status[0].toUpperCase() + req.status.substring(1);
    final note = (req.note != null && req.note!.isNotEmpty)
        ? '\nStudent Note: ${req.note}'
        : '';
    Share.share(
      'Correction Review\n\n'
      'Student: ${req.studentName}\n'
      'Class: ${req.className}  •  Roll: ${req.rollNo}\n'
      'Status: $statusLabel\n\n'
      'Requested Changes:\n$changedFields$note',
      subject: 'Correction Request – ${req.studentName}',
    );
  }

  Future<void> _showRejectReasonDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Correction Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a reason for rejection (optional):'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Photo is unclear, please resubmit',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final reason = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
      await _handleAction(false, reason: reason);
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = _repo.getById(widget.requestId);
    if (req == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Correction Review')),
          body: const Center(child: Text('Request not found')));
    }

    final current = _repo.studentData(req.studentId) ?? {};
    final isPending = req.status == 'pending';
    final allFields = {...current.keys, ...req.requestedChanges.keys}.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correction Review'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _share(req),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _StatusBadge(req.status),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            req.studentName
                                .trim()
                                .split(' ')
                                .map((w) => w[0])
                                .take(2)
                                .join(),
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.studentName,
                                style: AppTypography.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              'Class ${req.className}  •  Roll ${req.rollNo}',
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primary.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Column headers
                  Row(
                    children: [
                      Expanded(
                        child: _ColHeader(
                          icon: Icons.history_rounded,
                          label: 'Current Data',
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ColHeader(
                          icon: Icons.edit_rounded,
                          label: 'Requested Change',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Side-by-side comparison
                  ...allFields.map((field) {
                    final oldVal = current[field];
                    final newVal = req.requestedChanges[field];
                    final isChanged = newVal != null && newVal != oldVal;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _DataCell(
                                label: field,
                                value: oldVal ?? '—',
                                highlight: false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DataCell(
                                label: field,
                                value: newVal ?? oldVal ?? '—',
                                highlight: isChanged),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Note from student
                  if (req.note != null && req.note!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.sticky_note_2_rounded,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text('Note from Student',
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.warning)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.25)),
                      ),
                      child: Text(req.note!, style: AppTypography.bodyMedium),
                    ),
                  ],

                  // Teacher rejection note
                  if (req.teacherNote != null &&
                      req.teacherNote!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.cancel_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        Text('Rejection Reason',
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.error)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error.withOpacity(0.25)),
                      ),
                      child: Text(req.teacherNote!,
                          style: AppTypography.bodyMedium),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Action bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: isPending
                  ? Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Reject',
                            icon: Icons.close_rounded,
                            color: AppColors.error,
                            isLoading: _isProcessing,
                            onTap: () => _showRejectReasonDialog(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            label: 'Approve Changes',
                            icon: Icons.check_rounded,
                            color: AppColors.success,
                            isLoading: _isProcessing,
                            onTap: () => _handleAction(true),
                          ),
                        ),
                      ],
                    )
                  : _ActionButton(
                      label: 'Back to Class',
                      icon: Icons.arrow_back_rounded,
                      color: AppColors.primary,
                      isLoading: false,
                      onTap: () => context.pop(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = status == 'pending'
        ? AppColors.warning
        : status == 'approved'
            ? AppColors.success
            : AppColors.error;
    final icon = status == 'pending'
        ? Icons.hourglass_top_rounded
        : status == 'approved'
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ColHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.labelMedium.copyWith(
                color: color.withOpacity(0.8), fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DataCell extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _DataCell(
      {required this.label, required this.value, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withOpacity(0.08)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlight ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STUDENT-SPECIFIC VERIFY & CORRECT SCREEN
// ═══════════════════════════════════════════════════════════════════
class StudentVerifyScreen extends StatefulWidget {
  final String studentId; // URL path param, e.g. '01'
  const StudentVerifyScreen({super.key, required this.studentId});

  @override
  State<StudentVerifyScreen> createState() => _StudentVerifyScreenState();
}

class _StudentVerifyScreenState extends State<StudentVerifyScreen> {
  final _repo = CorrectionsRepository.instance;
  bool _isProcessing = false;
  String? _processingId;

  Future<void> _act(String reqId, bool approve) async {
    setState(() {
      _isProcessing = true;
      _processingId = reqId;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (approve) {
      _repo.approve(reqId);
    } else {
      _repo.reject(reqId);
    }
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _processingId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve ? 'Changes approved!' : 'Request rejected.'),
      backgroundColor: approve ? AppColors.success : AppColors.error,
    ));
  }

  String _fmtDate(DateTime dt) {
    const months = [
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
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final repoId = 'student-${widget.studentId}';
    final requests = _repo.listByStudent(repoId);
    final pending = requests.where((r) => r.status == 'pending').toList();
    final past = requests.where((r) => r.status != 'pending').toList();
    final current = _repo.studentData(repoId) ?? {};

    final name = current['Name'] ??
        (requests.isNotEmpty ? requests.first.studentName : 'Student');
    final cls = current['Class'] ??
        (requests.isNotEmpty ? requests.first.className : '');
    final roll = current['Roll No.'] ?? widget.studentId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 148,
            pinned: true,
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            title: const Text('Verify & Correct'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary,
                      AppColors.secondary.withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppAvatar(name: name, size: 48),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: AppTypography.titleSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Class $cls  \u2022  Roll $roll',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.85)),
                                ),
                              ],
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
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Current student data ──────────────────────────
                if (current.isNotEmpty) ..._buildCurrentDataSection(current),

                // ── Pending corrections ───────────────────────────
                if (pending.isEmpty && past.isEmpty)
                  _NoPendingCard()
                else
                  ..._buildRequestSections(pending, past, current),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCurrentDataSection(Map<String, String> current) {
    return [
      _VerifySectionHeader(
        icon: Icons.person_rounded,
        label: 'Current Student Data',
        color: AppColors.primary,
      ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: current.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      e.key,
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value, style: AppTypography.bodyMedium),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildRequestSections(
    List<CorrectionRequest> pending,
    List<CorrectionRequest> past,
    Map<String, String> current,
  ) {
    return [
      if (pending.isNotEmpty) ..._buildPendingSection(pending, current),
      if (past.isNotEmpty) ..._buildPastSection(past, current),
    ];
  }

  List<Widget> _buildPendingSection(
      List<CorrectionRequest> pending, Map<String, String> current) {
    return [
      _VerifySectionHeader(
        icon: Icons.hourglass_top_rounded,
        label: 'Pending Corrections (${pending.length})',
        color: AppColors.warning,
      ),
      const SizedBox(height: 10),
      ...pending.map((req) => _VerifyCorrectionCard(
            req: req,
            current: current,
            isPending: true,
            isProcessing: _isProcessing && _processingId == req.id,
            onApprove: () => _act(req.id, true),
            onReject: () => _act(req.id, false),
            fmtDate: _fmtDate,
          )),
    ];
  }

  List<Widget> _buildPastSection(
      List<CorrectionRequest> past, Map<String, String> current) {
    return [
      const SizedBox(height: 8),
      _VerifySectionHeader(
        icon: Icons.history_rounded,
        label: 'Past Requests',
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
      const SizedBox(height: 10),
      ...past.map((req) => _VerifyCorrectionCard(
            req: req,
            current: current,
            isPending: false,
            isProcessing: false,
            onApprove: null,
            onReject: null,
            fmtDate: _fmtDate,
          )),
    ];
  }
}

class _VerifySectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _VerifySectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.titleSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      );
}

class _NoPendingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 52, color: AppColors.success.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text('No Pending Corrections',
                style: AppTypography.titleSmall
                    .copyWith(color: AppColors.success)),
            const SizedBox(height: 6),
            Text(
              'All student data has been verified.',
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _VerifyCorrectionCard extends StatelessWidget {
  final CorrectionRequest req;
  final Map<String, String> current;
  final bool isPending;
  final bool isProcessing;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final String Function(DateTime) fmtDate;

  const _VerifyCorrectionCard({
    required this.req,
    required this.current,
    required this.isPending,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final changedFields = req.requestedChanges.keys.toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppColors.warning.withOpacity(0.4)
              : Theme.of(context).colorScheme.outline.withOpacity(0.4),
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: date + status badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45)),
                const SizedBox(width: 4),
                Text(
                  fmtDate(req.submittedAt),
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                _StatusBadge(req.status),
              ],
            ),
          ),
          const Divider(height: 1),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _ColHeader(
                    icon: Icons.history_rounded,
                    label: 'Current Data',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ColHeader(
                    icon: Icons.edit_rounded,
                    label: 'Requested',
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Side-by-side comparison rows
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: changedFields.map((field) {
                final oldVal = current[field];
                final newVal = req.requestedChanges[field];
                final isChanged = newVal != null && newVal != oldVal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DataCell(
                          label: field,
                          value: oldVal ?? '\u2014',
                          highlight: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DataCell(
                          label: field,
                          value: newVal ?? '\u2014',
                          highlight: isChanged,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Note from student
          if (req.note != null && req.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(req.note!, style: AppTypography.bodySmall)),
                  ],
                ),
              ),
            ),
          // Approve / Reject (pending only)
          if (isPending) ..._buildActions(),
        ],
      ),
    );
  }

  List<Widget> _buildActions() => [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  isLoading: isProcessing,
                  onTap: onReject ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _ActionButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  isLoading: isProcessing,
                  onTap: isProcessing ? () {} : (onApprove ?? () {}),
                ),
              ),
            ],
          ),
        ),
      ];
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.isLoading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}
