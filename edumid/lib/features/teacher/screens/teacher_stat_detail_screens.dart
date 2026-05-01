import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'teacher_screens.dart' show StudentProfileScreen;

// ═══════════════════════════════════════════════════════════════════
// Model
// ═══════════════════════════════════════════════════════════════════
class _StudentEntry {
  final String name;
  final String className;
  final String rollNo;
  final String? badge;
  final String? statusAt;
  const _StudentEntry(this.name, this.className, this.rollNo,
      [this.badge, this.statusAt]);
}

// ─── Demo data ──────────────────────────────────────────────────────

const _idReadyStudents = <_StudentEntry>[];

const _pendingPhotoStudents = <_StudentEntry>[];

const _uncheckedStudents = <_StudentEntry>[];

const _readyToPrintStudents = <_StudentEntry>[];

const _printingStudents = <_StudentEntry>[];

const _deliveredStudents = <_StudentEntry>[];

const _dispatchedStudents = <_StudentEntry>[];

// ═══════════════════════════════════════════════════════════════════
// SHARED STAT DETAIL SCREEN  (Class picker → Student list)
// ═══════════════════════════════════════════════════════════════════

class _StatDetailScreen extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_StudentEntry> students;
  final Color? badgeColor;
  final bool showShare;

  const _StatDetailScreen({
    required this.title,
    required this.color,
    required this.icon,
    required this.students,
    this.badgeColor,
    this.showShare = false,
  });

  @override
  State<_StatDetailScreen> createState() => _StatDetailScreenState();
}

class _StatDetailScreenState extends State<_StatDetailScreen> {
  /// null = class picker view; non-null = student list for that class
  String? _selectedClass;
  String _search = '';

  /// Group students by class, preserving insertion order of classes
  Map<String, List<_StudentEntry>> get _byClass {
    final map = <String, List<_StudentEntry>>{};
    for (final s in widget.students) {
      map.putIfAbsent(s.className, () => []).add(s);
    }
    return map;
  }

  void _selectClass(String cls) => setState(() {
        _selectedClass = cls;
        _search = '';
      });

  void _backToClasses() => setState(() {
        _selectedClass = null;
        _search = '';
      });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedClass == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedClass != null) _backToClasses();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: _selectedClass == null
            ? _ClassPickerView(
                title: widget.title,
                color: widget.color,
                icon: widget.icon,
                byClass: _byClass,
                totalCount: widget.students.length,
                onClassTap: _selectClass,
              )
            : _StudentListView(
                title: widget.title,
                className: _selectedClass!,
                color: widget.color,
                badgeColor: widget.badgeColor,
                students: _byClass[_selectedClass!] ?? [],
                search: _search,
                onSearchChanged: (v) => setState(() => _search = v),
                onBack: _backToClasses,
                showShare: widget.showShare,
              ),
      ),
    );
  }
}

// ── Class picker view ───────────────────────────────────────────────

class _ClassPickerView extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Map<String, List<_StudentEntry>> byClass;
  final int totalCount;
  final ValueChanged<String> onClassTap;

  const _ClassPickerView({
    required this.title,
    required this.color,
    required this.icon,
    required this.byClass,
    required this.totalCount,
    required this.onClassTap,
  });

  @override
  Widget build(BuildContext context) {
    final classes = byClass.keys.toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 150,
          pinned: true,
          backgroundColor: color,
          foregroundColor: Colors.white,
          title: Text(title),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalCount Students  •  ${classes.length} Classes',
                                style: AppTypography.titleSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tap a class to view students',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final cls = classes[i];
                final count = byClass[cls]!.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassCard(
                    className: cls,
                    studentCount: count,
                    color: color,
                    onTap: () => onClassTap(cls),
                  ),
                );
              },
              childCount: classes.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String className;
  final int studentCount;
  final Color color;
  final VoidCallback onTap;
  const _ClassCard(
      {required this.className,
      required this.studentCount,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    className,
                    style: AppTypography.titleSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class $className',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$studentCount student${studentCount == 1 ? '' : 's'}',
                      style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$studentCount',
                  style: AppTypography.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Student list view ───────────────────────────────────────────────

class _StudentListView extends StatelessWidget {
  final String title;
  final String className;
  final Color color;
  final Color? badgeColor;
  final List<_StudentEntry> students;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  final bool showShare;

  const _StudentListView({
    required this.title,
    required this.className,
    required this.color,
    this.badgeColor,
    required this.students,
    required this.search,
    required this.onSearchChanged,
    required this.onBack,
    this.showShare = false,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = students
        .where((s) =>
            s.name.toLowerCase().contains(search.toLowerCase()) ||
            s.rollNo.contains(search))
        .toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 140,
          pinned: true,
          backgroundColor: color,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          title: Text('Class $className'),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${students.length} student${students.length == 1 ? '' : 's'} in Class $className',
                        style: AppTypography.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or roll no.',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: color, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        filtered.isEmpty
            ? const SliverFillRemaining(
                child: Center(child: Text('No students found')),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StudentTile(
                        student: filtered[i],
                        accentColor: color,
                        badgeColor: badgeColor,
                        showShare: showShare,
                        onTap: () {
                          final s = filtered[i];
                          Navigator.of(ctx).push(MaterialPageRoute(
                            builder: (_) => StudentProfileScreen(
                              studentId: s.rollNo,
                              studentName: s.name,
                              studentClass: s.className,
                              studentRoll: s.rollNo,
                              initialBadge: s.badge,
                            ),
                          ));
                        },
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
      ],
    );
  }
}

// ── Student tile ────────────────────────────────────────────────────

class _StudentTile extends StatelessWidget {
  final _StudentEntry student;
  final Color accentColor;
  final Color? badgeColor;
  final bool showShare;
  final VoidCallback? onMarkReceived;
  final VoidCallback? onTap;
  const _StudentTile(
      {required this.student,
      required this.accentColor,
      this.badgeColor,
      this.showShare = false,
      this.onMarkReceived,
      this.onTap});

  void _share() {
    final name = student.name;
    final cls = student.className;
    final roll = student.rollNo;
    final status = student.badge ?? 'In Progress';
    final updated =
        student.statusAt != null ? '\nUpdated: ${student.statusAt}' : '';
    Share.share(
      'Student ID Card Status\n\n'
      'Name: $name\n'
      'Class: $cls\n'
      'Roll No: $roll\n'
      'Status: $status$updated',
      subject: 'ID Card Status � $name',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: student.name, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Chip(
                                icon: Icons.numbers_rounded,
                                label: 'Roll ${student.rollNo}',
                                color: accentColor),
                            if (student.statusAt != null)
                              _Chip(
                                  icon: Icons.access_time_rounded,
                                  label: student.statusAt!,
                                  color: accentColor.withOpacity(0.7)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (student.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? accentColor).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        student.badge!,
                        style: AppTypography.labelSmall.copyWith(
                          color: badgeColor ?? accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (showShare) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Share with parent',
                      icon: Icon(Icons.share_rounded,
                          size: 20, color: accentColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: _share,
                    ),
                  ],
                ],
              ),
              if (onMarkReceived != null) ...[
                const SizedBox(height: 8),
                Divider(
                    height: 1,
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onMarkReceived,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: false,
                            onChanged: (_) => onMarkReceived!(),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            activeColor: const Color(0xFF0891B2),
                            side: const BorderSide(
                                color: Color(0xFF0891B2), width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mark as Received',
                          style: AppTypography.bodySmall.copyWith(
                            color: const Color(0xFF0891B2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ));
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PUBLIC SCREEN CLASSES
// ═══════════════════════════════════════════════════════════════════

class IdCardsReadyScreen extends StatelessWidget {
  const IdCardsReadyScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatDetailScreen(
        title: 'ID Cards Ready',
        color: Color(0xFF16A34A),
        icon: Icons.badge_rounded,
        students: _idReadyStudents,
        badgeColor: Color(0xFF16A34A),
      );
}

class PendingPhotosScreen extends StatelessWidget {
  const PendingPhotosScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatDetailScreen(
        title: 'Pending Photos',
        color: Color(0xFFD97706),
        icon: Icons.photo_camera_rounded,
        students: _pendingPhotoStudents,
        badgeColor: Color(0xFFD97706),
        showShare: true,
      );
}

class UncheckedDataScreen extends StatelessWidget {
  const UncheckedDataScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatDetailScreen(
        title: 'Unchecked Data',
        color: Color(0xFFD97706),
        icon: Icons.fact_check_rounded,
        students: _uncheckedStudents,
        badgeColor: Color(0xFFD97706),
        showShare: true,
      );
}

class ReadyToPrintScreen extends StatelessWidget {
  const ReadyToPrintScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatDetailScreen(
        title: 'Ready to Print',
        color: Color(0xFF0891B2),
        icon: Icons.print_rounded,
        students: _readyToPrintStudents,
      );
}

class PrintingScreen extends StatelessWidget {
  const PrintingScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatDetailScreen(
        title: 'Printing',
        color: AppColors.primary,
        icon: Icons.local_printshop_rounded,
        students: _printingStudents,
        badgeColor: AppColors.primary,
      );
}

class DeliveredScreen extends StatelessWidget {
  const DeliveredScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatDetailScreen(
        title: 'Delivered',
        color: Color(0xFF16A34A),
        icon: Icons.inventory_2_rounded,
        students: _deliveredStudents,
        badgeColor: Color(0xFF16A34A),
      );
}

// --------------------------------------------------------------------------
// DISPATCH STATUS SCREEN  (Ready / Dispatched / Delivered tabs)
// --------------------------------------------------------------------------

class DispatchStatusScreen extends StatefulWidget {
  const DispatchStatusScreen({super.key});

  @override
  State<DispatchStatusScreen> createState() => _DispatchStatusScreenState();
}

class _DispatchStatusScreenState extends State<DispatchStatusScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  String _search = '';

  late List<_StudentEntry> _dispatched;
  late List<_StudentEntry> _delivered;
  final _selectedRolls = <String>{};

  static const _tabLabels = ['Ready', 'Dispatched', 'Delivered'];
  static const _tabIcons = [
    Icons.inventory_rounded,
    Icons.local_shipping_rounded,
    Icons.check_circle_rounded,
  ];
  static const _tabColors = [
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFF0891B2),
  ];

  List<List<_StudentEntry>> get _data => [
        List.unmodifiable(_idReadyStudents),
        _dispatched,
        _delivered,
      ];

  @override
  void initState() {
    super.initState();
    _dispatched = List<_StudentEntry>.from(_dispatchedStudents);
    _delivered = List<_StudentEntry>.from(_deliveredStudents);
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      _searchCtrl.clear();
      if (mounted) setState(() => _selectedRolls.clear());
    });
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  void _markReceived(_StudentEntry s) {
    final now = DateTime.now();
    final months = [
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
      'Dec',
    ];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour < 12 ? 'AM' : 'PM';
    final timeStr = '${months[now.month - 1]} ${now.day}, $hour:$minute $ampm';
    setState(() {
      _dispatched.remove(s);
      _delivered.insert(
        0,
        _StudentEntry(s.name, s.className, s.rollNo, 'Delivered', timeStr),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${s.name} marked as received'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0891B2),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSelect(String rollNo) {
    setState(() {
      if (_selectedRolls.contains(rollNo)) {
        _selectedRolls.remove(rollNo);
      } else {
        _selectedRolls.add(rollNo);
      }
    });
  }

  void _selectAll() =>
      setState(() => _selectedRolls.addAll(_dispatched.map((s) => s.rollNo)));

  void _deselectAll() => setState(() => _selectedRolls.clear());

  void _submitDelivery() {
    if (_selectedRolls.isEmpty) return;
    final count = _selectedRolls.length;
    final now = DateTime.now();
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
      'Dec',
    ];
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour < 12 ? 'AM' : 'PM';
    final timeStr = '${months[now.month - 1]} ${now.day}, $hour:$minute $ampm';
    setState(() {
      final toMove =
          _dispatched.where((s) => _selectedRolls.contains(s.rollNo)).toList();
      for (final s in toMove) {
        _dispatched.remove(s);
        _delivered.insert(
          0,
          _StudentEntry(s.name, s.className, s.rollNo, 'Delivered', timeStr),
        );
      }
      _selectedRolls.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('$count student${count == 1 ? '' : 's'} marked as delivered'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0891B2),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_StudentEntry> _filtered(int ti) {
    if (_search.isEmpty) return List.unmodifiable(_data[ti]);
    final q = _search.toLowerCase();
    return _data[ti]
        .where((s) => s.name.toLowerCase().contains(q) || s.rollNo.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            title: const Text('Dispatch'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: const Color(0xFF16A34A),
                child: TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.55),
                  labelStyle: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w700),
                  tabs: List.generate(
                    3,
                    (i) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tabIcons[i], size: 14),
                          const SizedBox(width: 5),
                          Text(_tabLabels[i]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF16A34A), AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 58),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _DispatchChip(
                                label: '${_idReadyStudents.length} Ready'),
                            _DispatchChip(
                                label: '${_dispatched.length} Dispatched'),
                            _DispatchChip(
                                label: '${_delivered.length} Delivered'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name or roll no.',
                  hintStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: _tabColors[_tab.index], width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: List.generate(3, (ti) {
                  final list = _filtered(ti);
                  final color = _tabColors[ti];
                  if (list.isEmpty) {
                    return const Center(child: Text('No students found'));
                  }
                  // -- Dispatched tab: checkboxes + timeline ----------
                  if (ti == 1) {
                    final allSelected =
                        _selectedRolls.length == list.length && list.isNotEmpty;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${list.length} dispatched',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      allSelected ? _deselectAll : _selectAll,
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  icon: Icon(
                                    allSelected
                                        ? Icons.deselect_rounded
                                        : Icons.done_all_rounded,
                                    size: 16,
                                    color: color,
                                  ),
                                  label: Text(
                                    allSelected
                                        ? 'Deselect All'
                                        : 'Mark All Received',
                                    style: TextStyle(color: color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final s = list[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DispatchableTile(
                            student: s,
                            isSelected: _selectedRolls.contains(s.rollNo),
                            onToggle: (_) => _toggleSelect(s.rollNo),
                            onSubmit: () => _markReceived(s),
                            onTap: () => Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => StudentProfileScreen(
                                  studentId: s.rollNo,
                                  studentName: s.name,
                                  studentClass: s.className,
                                  studentRoll: s.rollNo,
                                  initialBadge: s.badge,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  // -- Ready / Delivered tabs -------------------------
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _StudentTile(
                      student: list[i],
                      accentColor: color,
                      badgeColor: color,
                      onTap: () {
                        final s = list[i];
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => StudentProfileScreen(
                            studentId: s.rollNo,
                            studentName: s.name,
                            studentClass: s.className,
                            studentRoll: s.rollNo,
                            initialBadge: s.badge,
                          ),
                        ));
                      },
                    ),
                  );
                }),
              ),
            ),
            // -- Submit button (Dispatched tab only) ---------------
            if (_tab.index == 1 && _selectedRolls.isNotEmpty)
              Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: _submitDelivery,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    'Submit ${_selectedRolls.length} Student${_selectedRolls.length == 1 ? '' : 's'} as Delivered',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DispatchChip extends StatelessWidget {
  final String label;
  const _DispatchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// Dispatched-tab tile: checkbox + pipeline timeline
// -------------------------------------------------------------------
class _DispatchableTile extends StatelessWidget {
  final _StudentEntry student;
  final bool isSelected;
  final ValueChanged<bool?> onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onSubmit; // single-card submit

  static const _dispatchColor = Color(0xFFD97706);
  static const _deliveredColor = Color(0xFF16A34A);

  const _DispatchableTile({
    required this.student,
    required this.isSelected,
    required this.onToggle,
    this.onTap,
    this.onSubmit,
  });

  bool get _isDelivered => student.badge == 'Delivered';

  Color get _badgeColor => _isDelivered ? _deliveredColor : _dispatchColor;

  /// Deterministic mock pipeline timestamps derived from roll number.
  static ({String ready, String printing, String dispatched}) _buildTimeline(
      _StudentEntry s) {
    final roll = int.tryParse(s.rollNo) ?? 1;
    final base = DateTime(2026, 3, 7, 8 + roll % 4, (roll * 7) % 60);
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
      'Dec',
    ];
    String fmt(DateTime dt) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, $h:$m $ap';
    }

    return (
      ready: fmt(base),
      printing: fmt(base.add(const Duration(hours: 1, minutes: 30))),
      dispatched: fmt(base.add(const Duration(hours: 4, minutes: 30))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tl = _buildTimeline(student);
    final subtitleStyle = AppTypography.caption.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
      height: 1.6,
    );
    final labelStyle = subtitleStyle.copyWith(fontWeight: FontWeight.w600);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? _dispatchColor.withOpacity(0.05)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _dispatchColor.withOpacity(0.45)
                : Theme.of(context).colorScheme.outline.withOpacity(0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Avatar ----------------------------------------------
            AppAvatar(name: student.name, size: 42),
            const SizedBox(width: 12),

            // -- Center: name + timeline text -------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${student.className}  �  Roll ${student.rollNo}',
                    style: subtitleStyle,
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: subtitleStyle,
                      children: [
                        TextSpan(text: 'Ready to print: ', style: labelStyle),
                        TextSpan(text: tl.ready),
                        const TextSpan(text: '\n'),
                        TextSpan(
                            text: 'Printing date and time: ',
                            style: labelStyle),
                        TextSpan(text: tl.printing),
                        const TextSpan(text: '\n'),
                        TextSpan(
                            text: 'Dispatched date and time: ',
                            style: labelStyle),
                        TextSpan(text: tl.dispatched),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // -- Right: badge + checkbox + submit ---------------------
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _badgeColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    student.badge ?? 'Dispatched',
                    style: AppTypography.labelSmall.copyWith(
                      color: _badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Checkbox row
                if (!_isDelivered) ...[
                  GestureDetector(
                    onTap: () => onToggle(!isSelected),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: onToggle,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            activeColor: _dispatchColor,
                            side: const BorderSide(
                                color: _dispatchColor, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Select',
                          style: AppTypography.caption.copyWith(
                              color: _dispatchColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Submit button
                  GestureDetector(
                    onTap: onSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _dispatchColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Submit',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
