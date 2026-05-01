import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

enum DayStatus { present, absent, holiday, leave, none }

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  DateTime _currentMonth = DateTime.now();
  late Map<int, DayStatus> _statusMap;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _generateDummyData();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _generateDummyData() {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    _statusMap = Map.fromIterable(
      List.generate(daysInMonth, (i) => i + 1),
      value: (d) {
        final day = d as int;
        if (day % 10 == 0) return DayStatus.holiday;
        if (day % 8 == 0) return DayStatus.leave;
        if (day % 7 == 0) return DayStatus.absent;
        return DayStatus.present;
      },
    );
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _generateDummyData();
    });
    _animController.forward(from: 0);
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _generateDummyData();
    });
    _animController.forward(from: 0);
  }

  Color _colorForStatus(DayStatus s) {
    switch (s) {
      case DayStatus.present:
        return AppColors.success;
      case DayStatus.absent:
        return AppColors.error;
      case DayStatus.holiday:
        return const Color(0xFF94A3B8);
      case DayStatus.leave:
        return AppColors.warning;
      default:
        return Colors.transparent;
    }
  }

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1B2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF152236) : const Color(0xFFF1F5F9);

    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    final slots = <int?>[];
    final leadingEmpty = (firstWeekday - 1) % 7;
    for (var i = 0; i < leadingEmpty; i++) slots.add(null);
    for (var d = 1; d <= daysInMonth; d++) slots.add(d);
    while (slots.length % 7 != 0) slots.add(null);

    final present =
        _statusMap.values.where((s) => s == DayStatus.present).length;
    final absent = _statusMap.values.where((s) => s == DayStatus.absent).length;
    final leave = _statusMap.values.where((s) => s == DayStatus.leave).length;
    final holiday =
        _statusMap.values.where((s) => s == DayStatus.holiday).length;
    final total = present + absent + leave + holiday;
    final percent = total == 0 ? 0 : ((present / total) * 100).round();

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == _currentMonth.year && today.month == _currentMonth.month;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Attendance',
          style: AppTypography.titleMedium.copyWith(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom +
                  kBottomNavigationBarHeight +
                  20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Month navigator ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NavButton(
                          icon: Icons.chevron_left_rounded, onTap: _prevMonth),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          Text(
                            _monthName(_currentMonth.month),
                            style: AppTypography.titleLarge.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            '${_currentMonth.year}',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      _NavButton(
                          icon: Icons.chevron_right_rounded, onTap: _nextMonth),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Donut chart card ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _DonutCard(
                    cardBg: cardBg,
                    present: present,
                    absent: absent,
                    leave: leave,
                    holiday: holiday,
                    percent: percent,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Stat cards ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _AttendanceStatCard(
                        label: 'Present',
                        value: present,
                        color: AppColors.success,
                        icon: Icons.check_circle_rounded,
                        cardBg: cardBg,
                      ),
                      const SizedBox(height: 10),
                      _AttendanceStatCard(
                        label: 'Absent',
                        value: absent,
                        color: AppColors.error,
                        icon: Icons.cancel_rounded,
                        cardBg: cardBg,
                      ),
                      const SizedBox(height: 10),
                      _AttendanceStatCard(
                        label: 'Leave',
                        value: leave,
                        color: AppColors.warning,
                        icon: Icons.umbrella_rounded,
                        cardBg: cardBg,
                      ),
                      const SizedBox(height: 10),
                      _AttendanceStatCard(
                        label: 'Holiday',
                        value: holiday,
                        color: const Color(0xFF94A3B8),
                        icon: Icons.celebration_rounded,
                        cardBg: cardBg,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Calendar header ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                    child: Column(
                      children: [
                        // Weekday row
                        Row(
                          children: [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun'
                          ]
                              .map(
                                (d) => Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),

                        // Calendar grid
                        LayoutBuilder(builder: (ctx, gc) {
                          final cellW = gc.maxWidth / 7.0;
                          final cellH = (cellW * 1.15).clamp(44.0, 64.0);
                          return SizedBox(
                            height: cellH * (slots.length / 7),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                              ),
                              itemCount: slots.length,
                              itemBuilder: (context, index) {
                                final day = slots[index];
                                if (day == null) return const SizedBox.shrink();
                                final status =
                                    _statusMap[day] ?? DayStatus.none;
                                final color = _colorForStatus(status);
                                final isToday =
                                    isCurrentMonth && day == today.day;
                                return _CalendarCell(
                                  day: day,
                                  color: color,
                                  isToday: isToday,
                                  status: status,
                                );
                              },
                            ),
                          );
                        }),

                        const SizedBox(height: 16),
                        Divider(
                            color: isDark ? Colors.white12 : Colors.black12),
                        const SizedBox(height: 12),

                        // Bottom summary grid
                        Row(
                          children: [
                            _CalSummaryCell(
                                label: 'Present',
                                value: '$present',
                                color: AppColors.success),
                            _CalSummaryCell(
                                label: 'Absent',
                                value: '$absent',
                                color: AppColors.error),
                            _CalSummaryCell(
                                label: 'Leave',
                                value: '$leave',
                                color: AppColors.warning),
                            _CalSummaryCell(
                                label: 'Holiday',
                                value: '$holiday',
                                color: const Color(0xFF94A3B8)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Attendance %',
                          style: AppTypography.bodySmall.copyWith(
                              color: isDark ? Colors.white38 : Colors.black45),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$percent%',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Navigation arrow button ──────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Icon(icon,
            color: isDark ? Colors.white70 : Colors.black54, size: 20),
      ),
    );
  }
}

// ── Donut chart card ─────────────────────────────────────────────────────────

class _DonutCard extends StatelessWidget {
  final Color cardBg;
  final int present;
  final int absent;
  final int leave;
  final int holiday;
  final int percent;

  const _DonutCard({
    required this.cardBg,
    required this.present,
    required this.absent,
    required this.leave,
    required this.holiday,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final total = present + absent + leave + holiday;
    final hasSections = total > 0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 3,
                    centerSpaceRadius: 65,
                    sections: hasSections
                        ? [
                            PieChartSectionData(
                              color: AppColors.success,
                              value: present.toDouble(),
                              radius: 28,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              color: AppColors.error,
                              value: absent.toDouble(),
                              radius: 28,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              color: AppColors.warning,
                              value: leave.toDouble(),
                              radius: 28,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              color: const Color(0xFF94A3B8),
                              value: holiday.toDouble(),
                              radius: 28,
                              showTitle: false,
                            ),
                          ]
                        : [
                            PieChartSectionData(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white12
                                  : Colors.black12,
                              value: 1,
                              radius: 28,
                              showTitle: false,
                            ),
                          ],
                  ),
                ),
                Builder(builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: AppTypography.headlineSmall.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Attendance Rate',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? Colors.white38 : Colors.black45,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LegendDot(color: AppColors.success, label: 'Present'),
              _LegendDot(color: AppColors.error, label: 'Absent'),
              _LegendDot(color: AppColors.warning, label: 'Leave'),
              _LegendDot(color: const Color(0xFF94A3B8), label: 'Holiday'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white60
                : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _AttendanceStatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final Color cardBg;

  const _AttendanceStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white60
                    : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$value',
            style: AppTypography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar cell ────────────────────────────────────────────────────────────

class _CalendarCell extends StatelessWidget {
  final int day;
  final Color color;
  final bool isToday;
  final DayStatus status;

  const _CalendarCell({
    required this.day,
    required this.color,
    required this.isToday,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final hasStatus = status != DayStatus.none;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Text(
            '$day',
            style: AppTypography.labelSmall.copyWith(
              color: isToday
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white54 : Colors.black45),
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              fontSize: 10,
              height: 1.2,
            ),
          );
        }),
        const SizedBox(height: 3),
        Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: hasStatus ? color.withOpacity(0.18) : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(
                      color: isDark ? Colors.white54 : Colors.black45,
                      width: 1.5)
                  : null,
            ),
            child: hasStatus
                ? Center(
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          );
        }),
      ],
    );
  }
}

// ── Calendar bottom summary cell ─────────────────────────────────────────────

class _CalSummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CalSummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white38
                  : Colors.black45,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
