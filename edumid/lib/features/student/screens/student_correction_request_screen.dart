import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../corrections/corrections_repository.dart';

class StudentCorrectionRequestScreen extends StatefulWidget {
  const StudentCorrectionRequestScreen({super.key});

  @override
  State<StudentCorrectionRequestScreen> createState() =>
      _StudentCorrectionRequestScreenState();
}

class _StudentCorrectionRequestScreenState
    extends State<StudentCorrectionRequestScreen> {
  static const _blue = AppColors.primary;

  final Map<String, String> _current = {
    'Name': 'Arjun Sharma',
    'Class': 'X - A',
    'Roll No.': '23',
    'DOB': '15 Jan 2008',
    'Blood Group': 'B+',
    'Phone': '+91 98765 43210',
    'Address': '123 School Lane, City',
  };

  // Icons for each field
  static const Map<String, IconData> _fieldIcons = {
    'Name': Icons.person_rounded,
    'Class': Icons.class_rounded,
    'Roll No.': Icons.numbers_rounded,
    'DOB': Icons.cake_rounded,
    'Blood Group': Icons.water_drop_rounded,
    'Phone': Icons.phone_rounded,
    'Address': Icons.location_on_rounded,
  };

  bool _editing = false;
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final e in _current.entries)
        e.key: TextEditingController(text: e.value)
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _submitRequest() {
    final requested = <String, String>{};
    for (final k in _controllers.keys) {
      final val = _controllers[k]!.text.trim();
      if (val != _current[k]) requested[k] = val;
    }
    if (requested.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected')),
      );
      return;
    }
    CorrectionsRepository.instance.createRequest(
      studentId: 'student-23',
      studentName: _current['Name']!,
      className: _current['Class']!,
      rollNo: _current['Roll No.']!,
      requestedChanges: requested,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Correction request submitted successfully'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            title: const Text('Correction Request'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      // Avatar with white ring
                      Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const AppAvatar(name: 'Arjun Sharma', size: 80),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Arjun Sharma',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HeaderChip(
                              icon: Icons.class_rounded, label: 'Class X-A'),
                          const SizedBox(width: 8),
                          _HeaderChip(
                              icon: Icons.numbers_rounded,
                              label: 'Roll No. 23'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Student Info Card ───────────────────────────────
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.assignment_ind_rounded,
                                color: _blue, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('Student Details',
                              style: AppTypography.titleSmall
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      ..._current.entries.map((e) => _DetailRow(
                            label: e.key,
                            value: e.value,
                            icon: _fieldIcons[e.key] ?? Icons.info_outline,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Action button ───────────────────────────────────
                if (!_editing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Request Correction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: AppTypography.labelMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                // ── Edit Form ───────────────────────────────────────
                if (_editing) ...[
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.edit_note_rounded,
                                  color: Colors.orange, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Edit Fields',
                                  style: AppTypography.titleSmall
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // reset controllers
                                for (final e in _current.entries) {
                                  _controllers[e.key]!.text = e.value;
                                }
                                setState(() => _editing = false);
                              },
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Cancel'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  textStyle: AppTypography.labelSmall),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Only modify the fields that need correction.',
                          style: AppTypography.caption.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._controllers.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                controller: e.value,
                                decoration: InputDecoration(
                                  hintText: e.key,
                                  prefixIcon: Icon(
                                      _fieldIcons[e.key] ?? Icons.info_outline,
                                      size: 18,
                                      color: _blue),
                                  filled: true,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.4))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.4))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: _blue, width: 2)),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitRequest,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Submit Correction Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: AppTypography.labelMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  static const _blue = AppColors.primary;
  const _DetailRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _blue, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      fontSize: 11,
                    )),
                Text(value,
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
