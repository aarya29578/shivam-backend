// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

// ─── helpers shared with teacher_screens.dart PDF ───────────────
String _attFmtDate(DateTime dt) {
  const m = [
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
  return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ═══════════════════════════════════════════════════════════════════
// ATTENDANCE REPORT — DATA MODEL
// ═══════════════════════════════════════════════════════════════════

class TReportStudent {
  final String name;
  final String roll;
  final int presentDays;
  final int totalDays;
  const TReportStudent(this.name, this.roll, this.presentDays, this.totalDays);
  double get percentage => presentDays / totalDays * 100;
  String get grade => percentage >= 90
      ? 'A'
      : percentage >= 75
          ? 'B'
          : percentage >= 60
              ? 'C'
              : 'D';
}

// ═══════════════════════════════════════════════════════════════════
// ATTENDANCE REPORT SCREEN
// ═══════════════════════════════════════════════════════════════════

class TAttendanceReportScreen extends StatefulWidget {
  final String className;
  final int total;
  const TAttendanceReportScreen({
    super.key,
    required this.className,
    required this.total,
  });

  @override
  State<TAttendanceReportScreen> createState() =>
      _TAttendanceReportScreenState();
}

class _TAttendanceReportScreenState extends State<TAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  static const _green = AppColors.success;
  static const _purple = AppColors.primary;
  late TabController _tabCtrl;
  String _rangeFilter = 'This Month';
  String _statusFilter = 'All';

  static final _students = [
    const TReportStudent('Rahul Kumar', '01', 22, 26),
    const TReportStudent('Anita Singh', '02', 26, 26),
    const TReportStudent('Suresh Mehta', '03', 18, 26),
    const TReportStudent('Kavita Joshi', '04', 24, 26),
    const TReportStudent('Vijay Mishra', '05', 20, 26),
    const TReportStudent('Rekha Pant', '06', 26, 26),
    const TReportStudent('Deepak Raj', '07', 15, 26),
    const TReportStudent('Neha Gupta', '08', 21, 26),
    const TReportStudent('Arjun Singh', '09', 25, 26),
    const TReportStudent('Priya Patel', '10', 19, 26),
  ];

  List<TReportStudent> get _filtered {
    if (_statusFilter == 'Low (<75%)') {
      return _students.where((s) => s.percentage < 75).toList();
    } else if (_statusFilter == 'Good (>=75%)') {
      return _students.where((s) => s.percentage >= 75).toList();
    }
    return _students;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePdf(
      {bool individual = false, TReportStudent? student}) async {
    final fontRegular = await PdfGoogleFonts.nunitoSansRegular();
    final fontBold = await PdfGoogleFonts.nunitoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);
    final doc = pw.Document(title: 'Attendance Report', author: 'EduMid');
    final title = individual && student != null
        ? 'Attendance Report - ${student.name}'
        : 'Attendance Report - ${widget.className}';

    doc.addPage(pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 40, 32, 40),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor(0.063, 0.725, 0.506))),
                  pw.Text(
                      'Period: $_rangeFilter  |  Class: ${widget.className}',
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('EduMid School',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generated: ${_attFmtDate(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 7.5, color: PdfColors.grey500)),
                ],
              ),
            ],
          ),
          pw.Divider(
              color: const PdfColor(0.063, 0.725, 0.506), thickness: 1.2),
          pw.SizedBox(height: 6),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('EduMid - Attendance Report',
              style:
                  const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey400)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style:
                  const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey400)),
        ],
      ),
      build: (_) => [
        if (individual && student != null) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(student.name,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Roll No: ${student.roll}  |  Class: ${widget.className}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
                pw.SizedBox(height: 14),
                pw.Row(children: [
                  _pdfMiniStat(
                      'Present', '${student.presentDays}', PdfColors.green700),
                  pw.SizedBox(width: 10),
                  _pdfMiniStat(
                      'Absent',
                      '${student.totalDays - student.presentDays}',
                      PdfColors.red700),
                  pw.SizedBox(width: 10),
                  _pdfMiniStat(
                      'Total', '${student.totalDays}', PdfColors.grey700),
                  pw.SizedBox(width: 10),
                  _pdfMiniStat(
                      'Rate',
                      '${student.percentage.toStringAsFixed(1)}%',
                      const PdfColor(0.063, 0.725, 0.506)),
                ]),
              ],
            ),
          ),
        ] else ...[
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColor(0.063, 0.725, 0.506)),
                children: ['Name', 'Roll', 'Present', 'Absent', 'Total', 'Rate']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                        ))
                    .toList(),
              ),
              ..._students.map(
                (s) => pw.TableRow(
                  children: [
                    s.name,
                    s.roll,
                    '${s.presentDays}',
                    '${s.totalDays - s.presentDays}',
                    '${s.totalDays}',
                    '${s.percentage.toStringAsFixed(1)}%',
                  ]
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(cell,
                                style: const pw.TextStyle(fontSize: 8.5)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Attendance_Report.pdf',
    );
  }

  pw.Widget _pdfMiniStat(String label, String value, PdfColor color) =>
      pw.Container(
        width: 75,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outline;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text('Report - ${widget.className}'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Export class PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => _generatePdf(),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Class Report'),
            Tab(text: 'Individual'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filters bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _purple.withOpacity(0.05),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['This Month', 'Last Month', 'Last 30 Days']
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: _rangeFilter == f,
                                  selectedColor: _purple.withOpacity(0.18),
                                  labelStyle: TextStyle(
                                    color:
                                        _rangeFilter == f ? _purple : onSurface,
                                    fontSize: 12,
                                    fontWeight: _rangeFilter == f
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _rangeFilter = f),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: _statusFilter,
                  onSelected: (v) => setState(() => _statusFilter = v),
                  itemBuilder: (_) => ['All', 'Good (>=75%)', 'Low (<75%)']
                      .map((v) => PopupMenuItem(value: v, child: Text(v)))
                      .toList(),
                  child: Chip(
                    label: Text(_statusFilter,
                        style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.filter_list_rounded, size: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildClassReport(surface, outline, onSurface),
                _buildIndividualReport(surface, outline, onSurface),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassReport(Color surface, Color outline, Color onSurface) {
    final totalPresent = _students.fold(0, (s, e) => s + e.presentDays);
    final totalDays = _students.fold(0, (s, e) => s + e.totalDays);
    final avgPct = totalPresent / totalDays * 100;
    final aboveThreshold = _students.where((s) => s.percentage >= 75).length;
    final belowThreshold = _students.where((s) => s.percentage < 75).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: _purple.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Class Summary',
                  style: AppTypography.labelLarge.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttStat('${_students.length}', 'Students', Colors.white),
                  _AttStat('${avgPct.toStringAsFixed(1)}%', 'Avg Rate',
                      Colors.white),
                  _AttStat('$aboveThreshold', '>=75%', Colors.white),
                  _AttStat('$belowThreshold', '<75%',
                      Colors.white.withOpacity(0.75)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 280.ms),
        const SizedBox(height: 20),
        Row(children: [
          Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: _purple, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('Student-wise Attendance',
              style: AppTypography.labelLarge
                  .copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ..._filtered.asMap().entries.map((e) {
          final s = e.value;
          final absent = s.totalDays - s.presentDays;
          final color = s.percentage >= 90
              ? _green
              : s.percentage >= 75
                  ? const Color(0xFFF59E0B)
                  : Colors.redAccent;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: outline.withOpacity(0.15)),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.12),
                  child: Text(s.name[0],
                      style: AppTypography.labelSmall
                          .copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(s.name,
                              style: AppTypography.labelMedium
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ),
                        Text('Roll ${s.roll}',
                            style: AppTypography.caption
                                .copyWith(color: onSurface.withOpacity(0.45))),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.presentDays / s.totalDays,
                          color: color,
                          backgroundColor: color.withOpacity(0.1),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                          '${s.presentDays}P  ${absent}A  / ${s.totalDays} days',
                          style: AppTypography.caption
                              .copyWith(color: onSurface.withOpacity(0.5))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${s.percentage.toStringAsFixed(1)}%',
                      style: AppTypography.labelSmall
                          .copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          )
              .animate(
                  key: ValueKey(s.roll),
                  delay: Duration(milliseconds: 40 * e.key))
              .fadeIn(duration: 200.ms)
              .slideX(begin: 0.04, end: 0);
        }),
      ],
    );
  }

  Widget _buildIndividualReport(Color surface, Color outline, Color onSurface) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = _students[i];
        final absent = s.totalDays - s.presentDays;
        final color = s.percentage >= 90
            ? _green
            : s.percentage >= 75
                ? const Color(0xFFF59E0B)
                : Colors.redAccent;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withOpacity(0.12),
                  child: Text(s.name[0],
                      style: AppTypography.titleSmall
                          .copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: AppTypography.labelLarge
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text('Roll ${s.roll}  ·  ${widget.className}',
                          style: AppTypography.caption
                              .copyWith(color: onSurface.withOpacity(0.5))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${s.percentage.toStringAsFixed(1)}%',
                      style: AppTypography.labelMedium
                          .copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _AttStat('${s.presentDays}', 'Present', _green)),
                Expanded(
                    child: _AttStat('$absent', 'Absent', Colors.redAccent)),
                Expanded(
                    child: _AttStat(
                        '${s.totalDays}', 'Total', onSurface.withOpacity(0.5))),
                Expanded(child: _AttStat(s.grade, 'Grade', color)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: s.presentDays / s.totalDays,
                  color: color,
                  backgroundColor: color.withOpacity(0.1),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export Individual PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _generatePdf(individual: true, student: s),
                ),
              ),
            ],
          ),
        )
            .animate(
                key: ValueKey(s.roll), delay: Duration(milliseconds: 50 * i))
            .fadeIn(duration: 200.ms)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _AttStat extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _AttStat(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(val,
            style: AppTypography.titleSmall
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(lbl,
            style: AppTypography.caption.copyWith(color: col.withOpacity(0.8))),
      ]);
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCT CATALOGUE — DATA MODELS
// ═══════════════════════════════════════════════════════════════════

class TCatalogueProduct {
  final String name;
  final String category;
  final String description;
  final String unit;
  final IconData icon;
  const TCatalogueProduct({
    required this.name,
    required this.category,
    required this.description,
    required this.unit,
    required this.icon,
  });
}

class TPurchaseSuggestion {
  final TCatalogueProduct product;
  final String quantity;
  final String? note;
  final DateTime submittedAt;
  const TPurchaseSuggestion({
    required this.product,
    required this.quantity,
    this.note,
    required this.submittedAt,
  });
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCT CATALOGUE BANNER
// ═══════════════════════════════════════════════════════════════════

class TProductCatalogueBanner extends StatelessWidget {
  final VoidCallback onTap;
  const TProductCatalogueBanner({super.key, required this.onTap});
  static const _orange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _orange.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: _orange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Catalogue',
                      style: AppTypography.labelLarge.copyWith(
                          color: _orange, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Browse supplies & raise purchase requests to admin',
                      style: AppTypography.bodySmall
                          .copyWith(color: _orange.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _orange, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCT CATALOGUE SCREEN
// ═══════════════════════════════════════════════════════════════════

class TProductCatalogueScreen extends StatefulWidget {
  const TProductCatalogueScreen({super.key});
  @override
  State<TProductCatalogueScreen> createState() =>
      _TProductCatalogueScreenState();
}

class _TProductCatalogueScreenState extends State<TProductCatalogueScreen>
    with SingleTickerProviderStateMixin {
  static const _orange = Color(0xFFF97316);
  late TabController _tabCtrl;
  String _categoryFilter = 'All';

  static final _products = [
    const TCatalogueProduct(
      name: 'A4 Printer Paper (500 sheets)',
      category: 'Paper',
      description:
          'Premium 80gsm A4 white paper suitable for laser & inkjet printers',
      unit: 'Ream',
      icon: Icons.description_rounded,
    ),
    const TCatalogueProduct(
      name: 'PVC ID Card Blank',
      category: 'ID Cards',
      description: 'CR80 standard size blank white PVC cards for ID printing',
      unit: 'Pack (100)',
      icon: Icons.credit_card_rounded,
    ),
    const TCatalogueProduct(
      name: 'ID Card Lanyard',
      category: 'ID Cards',
      description: 'Nylon neck lanyard with safety breakaway clip',
      unit: 'Pack (50)',
      icon: Icons.local_offer_rounded,
    ),
    const TCatalogueProduct(
      name: 'ID Card Holder',
      category: 'ID Cards',
      description: 'Transparent vertical badge holder with slot',
      unit: 'Pack (100)',
      icon: Icons.badge_rounded,
    ),
    const TCatalogueProduct(
      name: 'Ballpoint Pen Set',
      category: 'Stationery',
      description: 'Blue ink ballpoint pens, medium tip, smooth writing',
      unit: 'Box (12)',
      icon: Icons.edit_rounded,
    ),
    const TCatalogueProduct(
      name: 'Whiteboard Marker Set',
      category: 'Classroom',
      description: 'Dry-erase markers in 4 colours: black, blue, red, green',
      unit: 'Set',
      icon: Icons.draw_rounded,
    ),
    const TCatalogueProduct(
      name: 'Attendance Register',
      category: 'Stationery',
      description:
          'Pre-printed attendance register with roll call columns, 30 days',
      unit: 'Piece',
      icon: Icons.fact_check_rounded,
    ),
    const TCatalogueProduct(
      name: 'Colour Printer Ink Cartridge',
      category: 'Printing',
      description: 'Compatible ink cartridge for colour ID card printing',
      unit: 'Piece',
      icon: Icons.print_rounded,
    ),
    const TCatalogueProduct(
      name: 'Lamination Pouch (A4)',
      category: 'Printing',
      description: '80 micron A4 thermal lamination pouches',
      unit: 'Pack (100)',
      icon: Icons.layers_rounded,
    ),
    const TCatalogueProduct(
      name: 'Register / Ledger Book',
      category: 'Stationery',
      description: 'A4 size hard-bound register, 200 pages, ruled',
      unit: 'Piece',
      icon: Icons.menu_book_rounded,
    ),
  ];

  final List<TPurchaseSuggestion> _suggestions = [];
  static const _categories = [
    'All',
    'Paper',
    'ID Cards',
    'Stationery',
    'Classroom',
    'Printing'
  ];

  List<TCatalogueProduct> get _filtered => _categoryFilter == 'All'
      ? _products
      : _products.where((p) => p.category == _categoryFilter).toList();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _showRequestDialog(TCatalogueProduct product) async {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.shopping_cart_rounded, color: _orange),
          const SizedBox(width: 8),
          const Text('Request Purchase'),
        ]),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name,
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.w700)),
              Text('Unit: ${product.unit}',
                  style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55))),
              const SizedBox(height: 14),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity Required',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.numbers_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter quantity' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note to Admin (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _suggestions.add(TPurchaseSuggestion(
          product: product,
          quantity: qtyCtrl.text.trim(),
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          submittedAt: DateTime.now(),
        ));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Purchase request for "${product.name}" sent to admin'),
          backgroundColor: _orange,
        ));
      }
    }
    qtyCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outline;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalogue'),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Catalogue'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('My Requests'),
                  const SizedBox(width: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _suggestions.isNotEmpty ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                          _suggestions.isEmpty ? '0' : '${_suggestions.length}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildCatalogueTab(surface, outline, onSurface),
          _buildRequestsTab(surface, outline, onSurface),
        ],
      ),
    );
  }

  Widget _buildCatalogueTab(Color surface, Color outline, Color onSurface) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = _categories[i];
              final sel = _categoryFilter == c;
              return ChoiceChip(
                label: Text(c),
                selected: sel,
                selectedColor: _orange.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: sel ? _orange : onSurface,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _categoryFilter = c),
              );
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = _filtered[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: _orange.withOpacity(0.15), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: _orange.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(p.icon, color: _orange, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(p.name,
                                  style: AppTypography.labelLarge
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(p.category,
                                  style: AppTypography.caption.copyWith(
                                      color: _orange,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(p.description,
                              style: AppTypography.bodySmall.copyWith(
                                  color: onSurface.withOpacity(0.55))),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.inventory_2_rounded,
                                size: 13, color: onSurface.withOpacity(0.4)),
                            const SizedBox(width: 4),
                            Text('Unit: ${p.unit}',
                                style: AppTypography.caption.copyWith(
                                    color: onSurface.withOpacity(0.5))),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.add_shopping_cart_rounded,
                                  size: 15),
                              label: const Text('Request'),
                              style: TextButton.styleFrom(
                                foregroundColor: _orange,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _showRequestDialog(p),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate(
                      key: ValueKey(p.name),
                      delay: Duration(milliseconds: 40 * i))
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: 0.04, end: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab(Color surface, Color outline, Color onSurface) {
    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 64, color: onSurface.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('No requests yet',
                style: AppTypography.titleSmall
                    .copyWith(color: onSurface.withOpacity(0.4))),
            const SizedBox(height: 4),
            Text('Go to Catalogue to raise a purchase request',
                style: AppTypography.bodySmall
                    .copyWith(color: onSurface.withOpacity(0.3))),
          ],
        ),
      );
    }
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = _suggestions[i];
        final dateStr =
            '${months[s.submittedAt.month - 1]} ${s.submittedAt.day}, ${s.submittedAt.year}';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _orange.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(s.product.icon, color: _orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.product.name,
                        style: AppTypography.labelMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Qty: ${s.quantity}  ·  ${s.product.unit}',
                        style: AppTypography.bodySmall
                            .copyWith(color: onSurface.withOpacity(0.6))),
                    if (s.note != null) ...[
                      const SizedBox(height: 3),
                      Text('Note: ${s.note}',
                          style: AppTypography.caption
                              .copyWith(color: onSurface.withOpacity(0.5))),
                    ],
                    const SizedBox(height: 6),
                    Text('Submitted: $dateStr',
                        style: AppTypography.caption
                            .copyWith(color: onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Pending',
                    style: AppTypography.caption.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        )
            .animate(delay: Duration(milliseconds: 50 * i))
            .fadeIn(duration: 200.ms);
      },
    );
  }
}
