import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/notification_store.dart';
import '../../../shared/models/order_request_store.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/user_profile_screen.dart';
import '../../../core/api/api_config.dart';
import '../../../shared/widgets/logout_helper.dart';
import '../../corrections/corrections_repository.dart';
import '../../reprint/reprint_repository.dart';
import 'teacher_attendance_extras.dart';
import '../../../core/navigation/auth_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/id_card_form_fill_screen.dart';
import '../../../shared/widgets/notice_screens.dart';

// ─── School data constants (shared with principal backend) ────────────────────
const String _kSchoolBase = ApiConfig.baseUrl;
String _kSchoolPrincipalId = '';

Dio _schoolDio() => Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
      // no special headers needed for direct VPS connection
    ));

Future<String> _ensureSchoolPrincipalId() async {
  if (_kSchoolPrincipalId.isNotEmpty) return _kSchoolPrincipalId;

  Map<String, dynamic>? user = await AuthService.instance.getStoredUser();
  user ??= await AuthService.instance.getProfile();
  final principalId = (user?['principalId'] ?? '').toString().trim();

  if (principalId.isNotEmpty) {
    _kSchoolPrincipalId = principalId;
  }
  return _kSchoolPrincipalId;
}

// ─── Teacher-side read-only data cache ───────────────────────────────────────
class _TeacherDataStore extends ChangeNotifier {
  static final instance = _TeacherDataStore._();
  _TeacherDataStore._();

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> staff = [];
  bool _loaded = false;
  bool isLoading = false;

  int get classCount => classes.length;
  int get teacherCount => teachers.length;
  int get studentCount => students.length;
  int get staffCount => staff.length;

  List<Map<String, dynamic>> studentsForClass(String className) =>
      students.where((s) => s['classOrDept'] == className).toList();

  Future<void> loadAll({bool force = false}) async {
    if (_loaded && !force) return;
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      final principalId = await _ensureSchoolPrincipalId();
      if (principalId.isEmpty) {
        debugPrint('[TeacherDataStore] ❌ principalId missing in session');
        _loaded = false;
        isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint('═' * 60);
      debugPrint('[TeacherDataStore] Starting loadAll()...');
      debugPrint('Base URL: $_kSchoolBase');
      debugPrint('Principal ID: $principalId');
      debugPrint('═' * 60);

      final dio = _schoolDio();

      // Build full URLs for debugging
      final classesUrl =
          '$_kSchoolBase/api/principal/classes?principalId=$principalId';
      final teachersUrl =
          '$_kSchoolBase/api/principal/members?principalId=$principalId&type=teacher';
      final studentsUrl =
          '$_kSchoolBase/api/principal/members?principalId=$principalId&type=student';
      final staffUrl =
          '$_kSchoolBase/api/principal/members?principalId=$principalId&type=staff';

      debugPrint('[Classes URL] $classesUrl');
      debugPrint('[Teachers URL] $teachersUrl');
      debugPrint('[Students URL] $studentsUrl');
      debugPrint('[Staff URL] $staffUrl');

      final results = await Future.wait([
        dio.get('$_kSchoolBase/api/principal/classes',
            queryParameters: {'principalId': principalId}),
        dio.get('$_kSchoolBase/api/principal/members',
            queryParameters: {'principalId': principalId, 'type': 'teacher'}),
        dio.get('$_kSchoolBase/api/principal/members',
            queryParameters: {'principalId': principalId, 'type': 'student'}),
        dio.get('$_kSchoolBase/api/principal/members',
            queryParameters: {'principalId': principalId, 'type': 'staff'}),
      ]);

      // Parse Classes
      final classesData = results[0].data;
      debugPrint('[Classes Response] Status: ${results[0].statusCode}');
      debugPrint(
          '[Classes Raw] Type: ${classesData.runtimeType}, Value: $classesData');
      classes = classesData is List
          ? List<Map<String, dynamic>>.from(classesData)
          : [];
      debugPrint('[Classes Parsed] Count: ${classes.length}, Data: $classes');

      // Parse Teachers
      final teachersData = results[1].data;
      debugPrint('[Teachers Response] Status: ${results[1].statusCode}');
      debugPrint(
          '[Teachers Raw] Type: ${teachersData.runtimeType}, Value: $teachersData');
      teachers = teachersData is List
          ? List<Map<String, dynamic>>.from(teachersData)
          : [];
      debugPrint('[Teachers Parsed] Count: ${teachers.length}');

      // Parse Students
      final studentsData = results[2].data;
      debugPrint('[Students Response] Status: ${results[2].statusCode}');
      debugPrint(
          '[Students Raw] Type: ${studentsData.runtimeType}, Value: $studentsData');
      students = studentsData is List
          ? List<Map<String, dynamic>>.from(studentsData)
          : [];
      debugPrint('[Students Parsed] Count: ${students.length}');

      // Parse Staff
      final staffData = results[3].data;
      debugPrint('[Staff Response] Status: ${results[3].statusCode}');
      debugPrint(
          '[Staff Raw] Type: ${staffData.runtimeType}, Value: $staffData');
      staff =
          staffData is List ? List<Map<String, dynamic>>.from(staffData) : [];
      debugPrint('[Staff Parsed] Count: ${staff.length}');

      _loaded = true;
      debugPrint('═' * 60);
      debugPrint('[TeacherDataStore] SUMMARY:');
      debugPrint('  Classes: ${classes.length} items');
      debugPrint('  Teachers: ${teachers.length} items');
      debugPrint('  Students: ${students.length} items');
      debugPrint('  Staff: ${staff.length} items');
      debugPrint('[TeacherDataStore] ✅ loadAll() completed successfully');
      debugPrint('═' * 60);
    } catch (e, st) {
      debugPrint('═' * 60);
      debugPrint('[TeacherDataStore] ❌ ERROR: $e');
      debugPrint('Stack: $st');
      debugPrint('═' * 60);
      _loaded = false;
    }
    isLoading = false;
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════════
// TEACHER DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final _store = _TeacherDataStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_update);
    _store.loadAll();
  }

  void _update() => setState(() {});

  @override
  void dispose() {
    _store.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Share App',
                onPressed: () => Share.share(
                  'EduMid – India\'s #1 School ID Card App 🎓\nInstall now: https://edumid.app',
                  subject: 'Check out EduMid App!',
                ),
              ),
              NotificationBadge(
                count: NotificationStore.unreadCount,
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppAvatar(name: 'Priya Nair', size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delhi Public School',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  Text(
                                    'Priya Nair',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Teacher',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StatChip(
                              label: 'Students',
                              value: _store.isLoading
                                  ? '…'
                                  : _store.studentCount.toString(),
                              icon: Icons.people_rounded,
                            ),
                            const SizedBox(width: 10),
                            _StatChip(
                              label: 'Pending',
                              value: '0',
                              icon: Icons.pending_rounded,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Overview Summary ─────────────────────────────────
                SectionHeader(title: 'Overview'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        label: 'Students',
                        value: _store.isLoading
                            ? '…'
                            : _store.studentCount.toString(),
                        subtitle: 'Total Enrolled',
                        icon: Icons.school_rounded,
                        color: AppColors.roleTeacher,
                        trend: 'Total enrolled',
                        onTap: () => context.go('/teacher/students'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverviewCard(
                        label: 'Dispatch',
                        value: '0',
                        subtitle: 'Ready',
                        icon: Icons.badge_rounded,
                        color: AppColors.success,
                        trend: '0% done',
                        onTap: () => context.push('/teacher/dispatch'),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),

                // ─── Corrections Card ─────────────────────────────────
                GestureDetector(
                  onTap: () => context.go('/teacher/corrections'),
                  child: const _CorrectionsCard(count: '0'),
                ).animate().fadeIn(delay: 270.ms),
                const SizedBox(height: 16),

                // ─── Data Collection ──────────────────────────────────
                _WorkflowSection(
                  title: 'Data Collection',
                  icon: Icons.analytics_rounded,
                  color: AppColors.warning,
                  items: [
                    _WorkflowItem(
                      label: 'Pending Photos',
                      value: '0',
                      icon: Icons.photo_camera_rounded,
                      color: AppColors.warning,
                      onTap: () => context.go('/teacher/pending-photos'),
                    ),
                    _WorkflowItem(
                      label: 'Unchecked Data',
                      value: '0',
                      icon: Icons.fact_check_rounded,
                      color: const Color(0xFFD97706),
                      onTap: () => context.go('/teacher/unchecked-data'),
                    ),
                    _WorkflowItem(
                      label: 'Form for New ID Card',
                      value: '',
                      icon: Icons.card_travel_rounded,
                      color: const Color(0xFF6D28D9),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IdCardFormFillScreen(
                            principalId: _kSchoolPrincipalId,
                            userId:
                                'teacher_001', // TODO: Get from auth/shared prefs
                            userEmail:
                                'teacher@school.com', // TODO: Get from auth/shared prefs
                            userName:
                                'Teacher Name', // TODO: Get from auth/shared prefs
                            role: 'teacher',
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 340.ms),
                const SizedBox(height: 16),

                // ─── Printing Pipeline ────────────────────────────────
                _PrintingPipeline(
                  readyToPrint: '0',
                  printing: '0',
                  delivered: '0',
                  onReadyToPrint: () => context.go('/teacher/printing-ready'),
                  onPrinting: () => context.go('/teacher/printing'),
                  onDelivered: () => context.go('/teacher/delivered'),
                ).animate().fadeIn(delay: 410.ms),
                const SizedBox(height: 16),

                // ─── Reprint Requests ─────────────────────────────────
                _ReprintRequestsBanner(
                  onTap: () => context.go('/teacher/reprint-requests'),
                ).animate().fadeIn(delay: 460.ms),
                const SizedBox(height: 16),

                // ─── Proof-Reading PDF ────────────────────────────────
                const _ProofReadPdfCard().animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 16),

                // ─── Product Catalogue ────────────────────────────────
                _CatalogueCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const _TProductCatalogueScreen()),
                  ),
                ).animate().fadeIn(delay: 580.ms),
                const SizedBox(height: 16),

                // Recent students
                SectionHeader(
                  title: 'Recent Students',
                  action: 'View All',
                  onAction: () => context.go('/teacher/students'),
                ),
                const SizedBox(height: 12),
                ..._buildStudentList(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStudentList(BuildContext context) {
    if (_store.isLoading) {
      return [
        const Center(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator()))
      ];
    }
    final recent = _store.students.take(3).toList();
    if (recent.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text('No students yet')),
        ),
      ];
    }
    return recent
        .map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              onTap: () {},
              child: Row(
                children: [
                  AppAvatar(name: s['name'] ?? '', size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['name'] ?? '', style: AppTypography.labelLarge),
                        Text(
                          'Class ${s['classOrDept'] ?? '—'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ),
        )
        .toList();
  }
}

class _SStudent {
  /// Real MongoDB ObjectId from the API (preferred for navigation).
  final String mongoId;
  final String name;
  final String className;
  final String roll;
  final bool hasPhoto;
  final String admissionNumber;
  final bool isComplete;
  final bool printingStarted;
  final bool dispatched;
  final bool delivered;

  /// Always use the MongoDB ObjectId when available; fall back to roll.
  String get id => mongoId.isNotEmpty ? mongoId : roll;
  const _SStudent(
    this.name,
    this.className,
    this.roll,
    this.hasPhoto, {
    this.mongoId = '',
    this.admissionNumber = '',
    this.isComplete = true,
    this.printingStarted = false,
    this.dispatched = false,
    this.delivered = false,
  });
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: AppTypography.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STUDENT LIST
// ═══════════════════════════════════════════════════════════════════
// REPRINT REQUESTS BANNER
// ═══════════════════════════════════════════════════════════════════
class _ReprintRequestsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ReprintRequestsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ReprintRepository.instance,
      builder: (context, _) {
        final pending = ReprintRepository.instance.requests
            .where((r) => r.status == 'pending')
            .length;
        final total = ReprintRepository.instance.requests.length;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.print_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reprint Requests',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        total == 0
                            ? 'No requests yet'
                            : '$pending pending · $total total',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pending > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pending',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// OVERVIEW CARD
// ═══════════════════════════════════════════════════════════════════
class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String trend;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trend,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CORRECTIONS CARD
// ═══════════════════════════════════════════════════════════════════
class _CorrectionsCard extends StatelessWidget {
  final String count;
  const _CorrectionsCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.edit_note_rounded, color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corrections Pending',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$count Requests',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.error, size: 20),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WORKFLOW SECTION + ITEM
// ═══════════════════════════════════════════════════════════════════
class _WorkflowSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_WorkflowItem> items;

  const _WorkflowSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          ...List.generate(
            items.length,
            (i) => Column(
              children: [
                items[i],
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    indent: 52,
                    endIndent: 16,
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.08),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WorkflowItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINTING PIPELINE
// ═══════════════════════════════════════════════════════════════════
class _PrintingPipeline extends StatelessWidget {
  final String readyToPrint;
  final String printing;
  final String delivered;
  final VoidCallback onReadyToPrint;
  final VoidCallback onPrinting;
  final VoidCallback onDelivered;

  const _PrintingPipeline({
    required this.readyToPrint,
    required this.printing,
    required this.delivered,
    required this.onReadyToPrint,
    required this.onPrinting,
    required this.onDelivered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.print_rounded,
                    color: Color(0xFF0891B2), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Printing Pipeline',
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                _PipelineStep(
                  label: 'Ready',
                  value: readyToPrint,
                  icon: Icons.print_rounded,
                  color: const Color(0xFF0891B2),
                  onTap: onReadyToPrint,
                ),
                const _PipelineConnector(),
                _PipelineStep(
                  label: 'Printing',
                  value: printing,
                  icon: Icons.local_printshop_rounded,
                  color: AppColors.primary,
                  onTap: onPrinting,
                ),
                const _PipelineConnector(),
                _PipelineStep(
                  label: 'Delivered',
                  value: delivered,
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF16A34A),
                  onTap: onDelivered,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PipelineStep({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineConnector extends StatelessWidget {
  const _PipelineConnector();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 1.5,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 10,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROOF-READING PDF
// ═══════════════════════════════════════════════════════════════════

String _proofPdfStageLabel(PrintStage s) {
  switch (s) {
    case PrintStage.pending:
      return 'Pending';
    case PrintStage.readyToPrint:
      return 'Ready to Print';
    case PrintStage.printing:
      return 'Printing';
    case PrintStage.dispatched:
      return 'Dispatched';
    case PrintStage.delivered:
      return 'Delivered';
  }
}

String _pdfFmtDate(DateTime dt) {
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

pw.Widget _pdfLabelValue(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 48,
            child: pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ),
          pw.Text(': ',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );

pw.Widget _pdfIdCardWidget(_PrintStudent student, String className) {
  final stageColor = student.status == PrintStage.delivered
      ? PdfColors.green700
      : student.status == PrintStage.dispatched
          ? PdfColors.teal700
          : student.status == PrintStage.printing
              ? const PdfColor(0.055, 0.569, 0.702) // #0E7490
              : PdfColors.grey600;
  return pw.Container(
    width: 242,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header bar
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: PdfColor(0.055, 0.569, 0.702),
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(5),
              topRight: pw.Radius.circular(5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('EduMid School',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5)),
              pw.Text('STUDENT ID CARD',
                  style: pw.TextStyle(
                      color: PdfColors.white.shade(0.7), fontSize: 6.5)),
            ],
          ),
        ),
        // Body
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Photo placeholder
              pw.Container(
                width: 58,
                height: 66,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 28,
                        height: 28,
                        decoration: const pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.grey300,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            student.name[0],
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('PHOTO',
                          style: const pw.TextStyle(
                              fontSize: 6, color: PdfColors.grey500)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              // Data fields
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(student.name,
                        style: pw.TextStyle(
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    _pdfLabelValue('Class', className),
                    _pdfLabelValue('Roll No', student.roll),
                    _pdfLabelValue(
                        'Status', _proofPdfStageLabel(student.status)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Status strip
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: stageColor,
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(5),
              bottomRight: pw.Radius.circular(5),
            ),
          ),
          child: pw.Text(
            _proofPdfStageLabel(student.status).toUpperCase(),
            style: pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5),
          ),
        ),
      ],
    ),
  );
}

Future<void> _generateProofPdf(BuildContext context) async {
  final fontRegular = await PdfGoogleFonts.nunitoSansRegular();
  final fontBold = await PdfGoogleFonts.nunitoSansBold();
  final fontItalic = await PdfGoogleFonts.nunitoSansItalic();
  final theme = pw.ThemeData.withFont(
    base: fontRegular,
    bold: fontBold,
    italic: fontItalic,
  );

  final doc = pw.Document(title: 'ID Card Proof Sheet', author: 'EduMid');

  for (final batch in _printingBatches) {
    if (batch.students.isEmpty) continue;
    final className = batch.batchName.replaceAll(' ID Cards', '');
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 36, 28, 36),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ID Card Proof Sheet',
                        style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor(0.055, 0.569, 0.702))),
                    pw.Text(batch.batchName,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('EduMid School',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'Generated: ${_pdfFmtDate(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 7.5, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(
                color: const PdfColor(0.055, 0.569, 0.702), thickness: 1.2),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Proof sheet - for internal review only',
                style: const pw.TextStyle(
                    fontSize: 7.5, color: PdfColors.grey400)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 7.5, color: PdfColors.grey400)),
          ],
        ),
        build: (_) => [
          pw.Wrap(
            spacing: 14,
            runSpacing: 14,
            children: batch.students
                .map((s) => _pdfIdCardWidget(s, className))
                .toList(),
          ),
        ],
      ),
    );
  }

  await Printing.layoutPdf(
    onLayout: (_) async => doc.save(),
    name: 'ID_Card_ProofSheet.pdf',
  );
}

class _ProofReadPdfCard extends StatelessWidget {
  const _ProofReadPdfCard();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _generateProofPdf(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate Proof-Reading PDF',
                      style: AppTypography.labelLarge
                          .copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'A4 preview of all ID cards with data & photo',
                      style: AppTypography.bodySmall
                          .copyWith(color: color.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINTING PROGRESS SCREEN
// ═══════════════════════════════════════════════════════════════════
class PrintingProgressScreen extends StatelessWidget {
  const PrintingProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final completed =
        _printingBatches.where((b) => b.deliveredAt != null).length;
    final inProgress = _printingBatches
        .where((b) => b.deliveredAt == null && b.readyAt != null)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printing Progress'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PipelineStat(
                        label: 'Batches',
                        value: '${_printingBatches.length}',
                        icon: Icons.layers_rounded),
                    _PipelineStat(
                        label: 'Delivered',
                        value: '$completed',
                        icon: Icons.inventory_2_rounded),
                    _PipelineStat(
                        label: 'In Progress',
                        value: '$inProgress',
                        icon: Icons.local_printshop_rounded),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final entry = _allStudents[i];
                  return _StudentProgressCard(
                    student: entry.student,
                    className: entry.className,
                  );
                },
                childCount: _allStudents.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Flatten all students from every batch into a single list.
  List<({_PrintStudent student, String className})> get _allStudents {
    final list = <({_PrintStudent student, String className})>[];
    for (final batch in _printingBatches) {
      final cls = batch.batchName.replaceAll(' ID Cards', '');
      for (final s in batch.students) {
        list.add((student: s, className: cls));
      }
    }
    return list;
  }
}

class _PipelineStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _PipelineStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.titleMedium
              .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: AppTypography.caption
              .copyWith(color: Colors.white.withOpacity(0.75)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINTING PROGRESS MODEL + DEMO DATA
// ═══════════════════════════════════════════════════════════════════

enum PrintStage { pending, readyToPrint, printing, dispatched, delivered }

class _PrintStudent {
  final String name;
  final String roll;
  final PrintStage status;
  const _PrintStudent(this.name, this.roll, this.status);
}

class PrintingBatch {
  final String batchName;
  final int totalCards;
  final DateTime? readyAt;
  final DateTime? printingAt;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final List<_PrintStudent> students;
  const PrintingBatch({
    required this.batchName,
    required this.totalCards,
    this.readyAt,
    this.printingAt,
    this.dispatchedAt,
    this.deliveredAt,
    this.students = const [],
  });
}

final _printingBatches = [
  PrintingBatch(
    batchName: 'Class X-A ID Cards',
    totalCards: 37,
    readyAt: DateTime(2026, 3, 7, 9, 5),
    printingAt: DateTime(2026, 3, 7, 11, 45),
    dispatchedAt: DateTime(2026, 3, 7, 14, 20),
    deliveredAt: DateTime(2026, 3, 8, 10, 0),
    students: [
      _PrintStudent('Rahul Kumar', '01', PrintStage.delivered),
      _PrintStudent('Anita Singh', '02', PrintStage.delivered),
      _PrintStudent('Suresh Mehta', '03', PrintStage.delivered),
      _PrintStudent('Kavita Joshi', '04', PrintStage.delivered),
    ],
  ),
  PrintingBatch(
    batchName: 'Class X-B ID Cards',
    totalCards: 34,
    readyAt: DateTime(2026, 3, 7, 10, 0),
    printingAt: DateTime(2026, 3, 7, 13, 30),
    dispatchedAt: DateTime(2026, 3, 8, 9, 15),
    students: [
      _PrintStudent('Mohit Sharma', '01', PrintStage.dispatched),
      _PrintStudent('Riya Verma', '02', PrintStage.dispatched),
      _PrintStudent('Deepak Nair', '03', PrintStage.dispatched),
      _PrintStudent('Pooja Iyer', '04', PrintStage.dispatched),
    ],
  ),
  PrintingBatch(
    batchName: 'Class IX-A ID Cards',
    totalCards: 40,
    readyAt: DateTime(2026, 3, 8, 8, 30),
    printingAt: DateTime(2026, 3, 8, 12, 0),
    students: [
      _PrintStudent('Priya Patel', '01', PrintStage.printing),
      _PrintStudent('Arun Das', '02', PrintStage.printing),
      _PrintStudent('Neha Gupta', '03', PrintStage.readyToPrint),
      _PrintStudent('Vikram Rao', '04', PrintStage.readyToPrint),
    ],
  ),
  PrintingBatch(
    batchName: 'Class IX-B ID Cards',
    totalCards: 38,
    readyAt: DateTime(2026, 3, 9, 9, 0),
    students: [
      _PrintStudent('Arjun Singh', '01', PrintStage.readyToPrint),
      _PrintStudent('Simran Kaur', '02', PrintStage.readyToPrint),
      _PrintStudent('Rahul Verma', '03', PrintStage.pending),
      _PrintStudent('Tanya Mishra', '04', PrintStage.pending),
    ],
  ),
];

class _StageInfo {
  final String label;
  final IconData icon;
  final String route;
  const _StageInfo(this.label, this.icon, this.route);
}

// ═══════════════════════════════════════════════════════════════════
// STUDENT PROGRESS CARD (flat list entry)
// ═══════════════════════════════════════════════════════════════════
class _StudentProgressCard extends StatelessWidget {
  final _PrintStudent student;
  final String className;
  const _StudentProgressCard({required this.student, required this.className});

  String _stageLabel(PrintStage stage) => switch (stage) {
        PrintStage.delivered => 'Delivered',
        PrintStage.dispatched => 'Dispatched',
        PrintStage.printing => 'Printing',
        PrintStage.readyToPrint => 'Ready to Print',
        PrintStage.pending => 'Pending',
      };

  IconData _stageIcon(PrintStage stage) => switch (stage) {
        PrintStage.delivered => Icons.inventory_2_rounded,
        PrintStage.dispatched => Icons.local_shipping_rounded,
        PrintStage.printing => Icons.local_printshop_rounded,
        PrintStage.readyToPrint => Icons.print_rounded,
        PrintStage.pending => Icons.hourglass_empty_rounded,
      };

  Color _stageColor(PrintStage stage, BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return switch (stage) {
      PrintStage.delivered => AppColors.success,
      PrintStage.dispatched => const Color(0xFF0891B2),
      PrintStage.printing => AppColors.warning,
      PrintStage.readyToPrint => AppColors.primary,
      PrintStage.pending => outline.withOpacity(0.5),
    };
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _stageColor(student.status, context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stageColor.withOpacity(0.2), width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: stageColor.withOpacity(0.12),
            child: Text(
              student.name[0],
              style: AppTypography.titleSmall
                  .copyWith(color: stageColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$className  ·  Roll ${student.roll}',
                  style: AppTypography.caption
                      .copyWith(color: onSurface.withOpacity(0.45)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(_stageIcon(student.status),
                        size: 13, color: stageColor),
                    const SizedBox(width: 4),
                    Text(
                      _stageLabel(student.status),
                      style: AppTypography.labelSmall.copyWith(
                          color: stageColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINTING PROGRESS CARD
// ═══════════════════════════════════════════════════════════════════
class _PrintingProgressCard extends StatefulWidget {
  final PrintingBatch batch;
  const _PrintingProgressCard({required this.batch});

  @override
  State<_PrintingProgressCard> createState() => _PrintingProgressCardState();
}

class _PrintingProgressCardState extends State<_PrintingProgressCard> {
  bool _expanded = false;

  static const _stages = [
    _StageInfo('Ready to Print', Icons.print_rounded, '/teacher/ready'),
    _StageInfo('Printing', Icons.local_printshop_rounded, '/teacher/printing'),
    _StageInfo('Dispatched', Icons.local_shipping_rounded, '/teacher/dispatch'),
    _StageInfo('Delivered', Icons.inventory_2_rounded, '/teacher/delivered'),
  ];

  DateTime? _dateFor(int i) => switch (i) {
        0 => widget.batch.readyAt,
        1 => widget.batch.printingAt,
        2 => widget.batch.dispatchedAt,
        3 => widget.batch.deliveredAt,
        _ => null,
      };

  String _fmt(DateTime dt) {
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
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ·  $h:$min $ampm';
  }

  String _stageLabel(PrintStage stage) => switch (stage) {
        PrintStage.delivered => 'Delivered ✅',
        PrintStage.dispatched => 'Dispatched 🚚',
        PrintStage.printing => 'Printing 🖨️',
        PrintStage.readyToPrint => 'Ready to Print 📋',
        PrintStage.pending => 'Pending ⏳',
      };

  Color _stageColor(PrintStage stage, BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return switch (stage) {
      PrintStage.delivered => AppColors.success,
      PrintStage.dispatched => const Color(0xFF0891B2),
      PrintStage.printing => AppColors.warning,
      PrintStage.readyToPrint => AppColors.primary,
      PrintStage.pending => outline.withOpacity(0.5),
    };
  }

  void _shareStudentProgress(_PrintStudent student) {
    final className = widget.batch.batchName.replaceAll(' ID Cards', '');
    final statusText = _stageLabel(student.status);
    final message = '📌 ID Card Printing Update\n\n'
        'Student: ${student.name}\n'
        'Class: $className\n'
        'Roll No: ${student.roll}\n'
        'Status: $statusText\n\n'
        'This update is shared via EduMid School Management System.';
    Share.share(message, subject: 'ID Card Status – ${student.name}');
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    const green = AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.badge_rounded,
                      color: Color(0xFF0891B2), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.batch.batchName,
                        style: AppTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${widget.batch.totalCards} cards',
                        style: AppTypography.caption
                            .copyWith(color: onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: outline.withOpacity(0.1)),
          // ── Timeline ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: List.generate(_stages.length, (i) {
                final stage = _stages[i];
                final dt = _dateFor(i);
                final done = dt != null;
                final isLast = i == _stages.length - 1;
                final nextDone = !isLast && _dateFor(i + 1) != null;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dot + vertical connector
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done ? green : outline.withOpacity(0.18),
                                border: Border.all(
                                  color:
                                      done ? green : outline.withOpacity(0.35),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 1.5,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  color: nextDone
                                      ? green.withOpacity(0.4)
                                      : outline.withOpacity(0.18),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Stage label + timestamp
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                          child: GestureDetector(
                            onTap: done ? () => context.go(stage.route) : null,
                            child: Row(
                              children: [
                                Icon(
                                  stage.icon,
                                  size: 14,
                                  color:
                                      done ? green : outline.withOpacity(0.4),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stage.label,
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          color: done
                                              ? green
                                              : onSurface.withOpacity(0.4),
                                          fontWeight: done
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      Text(
                                        done ? _fmt(dt) : 'Pending',
                                        style: AppTypography.caption.copyWith(
                                          color: done
                                              ? onSurface.withOpacity(0.55)
                                              : onSurface.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (done)
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 14,
                                    color: green.withOpacity(0.6),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // ── Students section ──
          if (widget.batch.students.isNotEmpty) ...[
            Divider(height: 1, color: outline.withOpacity(0.1)),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded,
                        size: 15, color: const Color(0xFF0891B2)),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.batch.students.length} Students',
                      style: AppTypography.labelSmall.copyWith(
                        color: const Color(0xFF0891B2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Share progress',
                      style: AppTypography.caption.copyWith(
                        color: onSurface.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded,
                          size: 18, color: onSurface.withOpacity(0.45)),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(height: 1, color: outline.withOpacity(0.08)),
                  ...widget.batch.students.map((student) {
                    final stageColor = _stageColor(student.status, context);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: stageColor.withOpacity(0.12),
                            child: Text(
                              student.name[0],
                              style: AppTypography.labelSmall.copyWith(
                                color: stageColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.name,
                                    style: AppTypography.labelSmall
                                        .copyWith(fontWeight: FontWeight.w600)),
                                Text(
                                  'Roll ${student.roll}  ·  ${_stageLabel(student.status)}',
                                  style: AppTypography.caption
                                      .copyWith(color: stageColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Share with parent',
                            icon: Icon(Icons.share_rounded,
                                size: 18, color: const Color(0xFF0891B2)),
                            onPressed: () => _shareStudentProgress(student),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STUDENT LIST SCREEN
// ═══════════════════════════════════════════════════════════════════

enum _SortOption {
  rollNo,
  nameAZ,
  admissionNo,
  incompleteFirst,
  missingPhotoFirst,
}

enum _StudentStatus {
  withoutPhoto,
  incomplete,
  readyToPrint,
  printing,
  dispatch,
  delivered,
}

_StudentStatus _statusOf(_SStudent s) {
  if (s.delivered == true) return _StudentStatus.delivered;
  if (s.dispatched == true) return _StudentStatus.dispatch;
  if (s.printingStarted == true) return _StudentStatus.printing;
  if (s.hasPhoto != true) return _StudentStatus.withoutPhoto;
  if (s.isComplete != true) return _StudentStatus.incomplete;
  return _StudentStatus.readyToPrint;
}

const _studentStatusLabel = {
  _StudentStatus.withoutPhoto: 'Without Photo',
  _StudentStatus.incomplete: 'Incomplete',
  _StudentStatus.readyToPrint: 'Ready to Print',
  _StudentStatus.printing: 'Printing',
  _StudentStatus.dispatch: 'Dispatch',
  _StudentStatus.delivered: 'Delivered',
};

const _studentStatusColor = {
  _StudentStatus.withoutPhoto: AppColors.warning,
  _StudentStatus.incomplete: AppColors.error,
  _StudentStatus.readyToPrint: AppColors.primary,
  _StudentStatus.printing: Color(0xFF7C3AED),
  _StudentStatus.dispatch: Color(0xFF0D9488),
  _StudentStatus.delivered: AppColors.success,
};

// Priority rank for auto-sort: lower = shown first
const _studentStatusPriority = {
  _StudentStatus.withoutPhoto: 0,
  _StudentStatus.incomplete: 1,
  _StudentStatus.readyToPrint: 2,
  _StudentStatus.printing: 3,
  _StudentStatus.dispatch: 4,
  _StudentStatus.delivered: 5,
};

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});
  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _searchCtrl = TextEditingController();
  final _store = _TeacherDataStore.instance;

  String? _filterClass;
  _SortOption _sort = _SortOption.rollNo;
  _StudentStatus? _statusFilter; // null = all

  // ── live-data getters ──────────────────────────────────────────────
  List<String> get _classes {
    final names = _store.classes
        .map((c) => (c['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
    return names;
  }

  String get _filter =>
      _filterClass ?? (_classes.isNotEmpty ? _classes[0] : '');

  List<_SStudent> get _students {
    return _store.students.map((s) {
      final mongoId = (s['id'] ?? s['_id'] ?? '').toString();
      final name = (s['name'] ?? '').toString();
      final cls = (s['classOrDept'] ?? '').toString();
      final roll = (s['rollNumber'] ?? '').toString();
      final phone = (s['phone'] ?? '').toString();
      // ignore: avoid_print
      print(
          'STUDENT ID: $mongoId name=$name roll=$roll profileImage=${s['profileImage']}');
      return _SStudent(
          name, cls, roll, (s['profileImage'] as String? ?? '').isNotEmpty,
          mongoId: mongoId, admissionNumber: phone);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_update);
    _store.loadAll();
  }

  void _update() => setState(() {});

  List<_SStudent> get _filtered {
    var list = _students
        .where((s) =>
            s.className == _filter &&
            s.name.toLowerCase().contains(_searchCtrl.text.toLowerCase()) &&
            (_statusFilter == null || _statusOf(s) == _statusFilter))
        .toList();

    // Apply explicit sort if chosen by user
    switch (_sort) {
      case _SortOption.nameAZ:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _SortOption.admissionNo:
        list.sort((a, b) {
          final ai = int.tryParse(a.admissionNumber) ?? 0;
          final bi = int.tryParse(b.admissionNumber) ?? 0;
          return ai.compareTo(bi);
        });
      case _SortOption.rollNo:
        // Even in roll-no mode, secondary sort by status priority
        list.sort((a, b) {
          final pa = _studentStatusPriority[_statusOf(a)]!;
          final pb = _studentStatusPriority[_statusOf(b)]!;
          if (pa != pb) return pa.compareTo(pb);
          final ai = int.tryParse(a.roll) ?? 0;
          final bi = int.tryParse(b.roll) ?? 0;
          return ai.compareTo(bi);
        });
      case _SortOption.incompleteFirst:
        list.sort((a, b) {
          if (a.isComplete != true && b.isComplete == true) return -1;
          if (a.isComplete == true && b.isComplete != true) return 1;
          return 0;
        });
      case _SortOption.missingPhotoFirst:
        list.sort((a, b) {
          if (a.hasPhoto != true && b.hasPhoto == true) return -1;
          if (a.hasPhoto == true && b.hasPhoto != true) return 1;
          return 0;
        });
    }
    return list;
  }

  String get _sortLabel => switch (_sort) {
        _SortOption.nameAZ => 'Name (A–Z)',
        _SortOption.admissionNo => 'Admission No.',
        _SortOption.rollNo => 'Roll No.',
        _SortOption.incompleteFirst => 'Incomplete First',
        _SortOption.missingPhotoFirst => 'Missing Photo First',
      };

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sort Students',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...[
                  (
                    _SortOption.rollNo,
                    'Roll Number',
                    Icons.format_list_numbered_rounded
                  ),
                  (
                    _SortOption.nameAZ,
                    'Name (A–Z)',
                    Icons.sort_by_alpha_rounded
                  ),
                  (
                    _SortOption.admissionNo,
                    'Admission Number',
                    Icons.confirmation_number_outlined
                  ),
                  (
                    _SortOption.incompleteFirst,
                    'Incomplete Data First',
                    Icons.warning_amber_rounded
                  ),
                  (
                    _SortOption.missingPhotoFirst,
                    'Missing Photo First',
                    Icons.no_photography_outlined
                  ),
                ].map((opt) {
                  final selected = _sort == opt.$1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _sort = opt.$1);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withOpacity(0.3)
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.25),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            opt.$3,
                            size: 20,
                            color: selected
                                ? AppColors.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.55),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt.$2,
                              style: AppTypography.labelMedium.copyWith(
                                color: selected ? AppColors.primary : null,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _store.removeListener(_update);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_store.isLoading && _classes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Students')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.go('/teacher/students/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Class filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _classes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _classes[i];
                final sel = c == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filterClass = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      c,
                      style: AppTypography.labelSmall.copyWith(
                        color: sel ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Status filter chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _StudentStatus.values.length + 1, // +1 for "All"
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                if (i == 0) {
                  final sel = _statusFilter == null;
                  return GestureDetector(
                    onTap: () => setState(() => _statusFilter = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sel
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        'All',
                        style: AppTypography.caption.copyWith(
                          color: sel
                              ? Theme.of(context).colorScheme.surface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }
                final status = _StudentStatus.values[i - 1];
                final sel = _statusFilter == status;
                final color = _studentStatusColor[status]!;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _statusFilter = sel ? null : status),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sel ? color : color.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      _studentStatusLabel[status]!,
                      style: AppTypography.caption.copyWith(
                        color: sel ? Colors.white : color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Count row + active sort indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${list.length} student${list.length == 1 ? '' : 's'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
                if (_statusFilter != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _studentStatusColor[_statusFilter!]!
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _studentStatusLabel[_statusFilter!]!,
                      style: AppTypography.caption.copyWith(
                        color: _studentStatusColor[_statusFilter!]!,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _showSortSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _sortLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Student list
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    title: 'No students found',
                    subtitle: 'Try adjusting your search or filters',
                    icon: Icons.search_off_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return PremiumCard(
                        onTap: () => context.go('/teacher/students/${s.id}'),
                        child: Row(
                          children: [
                            AppAvatar(name: s.name, size: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: AppTypography.labelLarge),
                                  Text(
                                    'Class ${s.className}  •  Roll ${s.roll}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.45),
                                    ),
                                  ),
                                  if (s.admissionNumber.isNotEmpty)
                                    Text(
                                      'Adm. ${s.admissionNumber}',
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                RoleBadge(
                                  label: _studentStatusLabel[_statusOf(s)]!,
                                  color: _studentStatusColor[_statusOf(s)]!,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final text =
                                    '🎓 Student Info\n\nName: ${s.name}\nClass: ${s.className}  •  Roll: ${s.roll}'
                                    '\nAdmission No: ${s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A'}'
                                    '\nPhoto: ${s.hasPhoto ? 'Uploaded ✓' : 'Pending'}'
                                    '\nData: ${s.isComplete ? 'Complete' : 'Incomplete'}'
                                    '\n\n— EduMid';
                                Share.share(text,
                                    subject: 'Student Info – ${s.name}');
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.share_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.45),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded),
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

// ═══════════════════════════════════════════════════════════════════
// CLASS FILTER SCREEN
// ═══════════════════════════════════════════════════════════════════
class ClassFilterScreen extends StatefulWidget {
  const ClassFilterScreen({super.key});
  @override
  State<ClassFilterScreen> createState() => _ClassFilterScreenState();
}

class _ClassFilterScreenState extends State<ClassFilterScreen> {
  final Set<String> _selected = {};

  static final _classes = [
    'Class VI',
    'Class VII',
    'Class VIII',
    'Class IX',
    'Class X',
    'Class XI',
    'Class XII',
  ];
  static final _sections = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter by Class'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _selected.clear()),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Class', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classes
                  .map(
                    (c) => FilterChip(
                      label: Text(c),
                      selected: _selected.contains(c),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selected.add(c);
                          } else {
                            _selected.remove(c);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('Select Section', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _sections
                  .map(
                    (s) => FilterChip(
                      label: Text('Section $s'),
                      selected: _selected.contains('sec_$s'),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selected.add('sec_$s');
                          } else {
                            _selected.remove('sec_$s');
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            GradientButton(
              label: 'Apply Filter (${_selected.length})',
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEARCH STUDENT
// ═══════════════════════════════════════════════════════════════════
class SearchStudentScreen extends StatefulWidget {
  const SearchStudentScreen({super.key});
  @override
  State<SearchStudentScreen> createState() => _SearchStudentScreenState();
}

class _SearchStudentScreenState extends State<SearchStudentScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  List<_SStudent> get _all => _TeacherDataStore.instance.students.map((s) {
        final mongoId = (s['id'] ?? s['_id'] ?? '').toString();
        final name = (s['name'] ?? '').toString();
        final cls = (s['classOrDept'] ?? '').toString();
        final roll = (s['rollNumber'] ?? '').toString();
        final phone = (s['phone'] ?? '').toString();
        return _SStudent(
            name, cls, roll, (s['profileImage'] as String? ?? '').isNotEmpty,
            mongoId: mongoId, admissionNumber: phone);
      }).toList();

  List<_SStudent> get _results => _ctrl.text.isEmpty
      ? []
      : _all
          .where((s) =>
              s.name.toLowerCase().contains(_ctrl.text.toLowerCase()) ||
              s.roll.contains(_ctrl.text))
          .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search by name or roll number...',
            border: InputBorder.none,
          ),
          style: AppTypography.bodyLarge,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _ctrl.clear();
                setState(() {});
              },
            ),
        ],
      ),
      body: _ctrl.text.isEmpty
          ? const EmptyState(
              title: 'Search Students',
              subtitle: 'Type a name or roll number to find students',
              icon: Icons.search_rounded,
            )
          : _results.isEmpty
              ? const EmptyState(
                  title: 'No results found',
                  subtitle: 'Try a different search term',
                  icon: Icons.search_off_rounded,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = _results[i];
                    return PremiumCard(
                      onTap: () => context.go('/teacher/students/${s.id}'),
                      child: Row(
                        children: [
                          AppAvatar(name: s.name, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: AppTypography.labelLarge),
                                Text(
                                  'Class ${s.className} • Roll ${s.roll}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STUDENT LOCK STORE
// ═══════════════════════════════════════════════════════════════════

class _LockData {
  final DateTime readyAt;
  DateTime? printingAt;
  DateTime? dispatchedAt;
  DateTime? deliveredAt;
  bool reprintRequested;

  _LockData({required this.readyAt}) : reprintRequested = false;

  PrintStage get currentStage {
    if (deliveredAt != null) return PrintStage.delivered;
    if (dispatchedAt != null) return PrintStage.dispatched;
    if (printingAt != null) return PrintStage.printing;
    return PrintStage.readyToPrint;
  }
}

class _StudentLockStore {
  static final Map<String, _LockData> _store = {};
  static final Set<String> _approved = {};

  static bool isLocked(String id) => _store.containsKey(id);
  static _LockData? getData(String id) => _store[id];
  static bool isApproved(String id) => _approved.contains(id);

  static void lock(String id) =>
      _store[id] = _LockData(readyAt: DateTime.now());

  /// Pre-initialise lock state from a pipeline badge string so that
  /// navigating from stat-detail screens shows the correct timeline.
  static void initFromBadge(String id, String badge) {
    if (_store.containsKey(id)) return; // already initialised
    final base = DateTime.now().subtract(const Duration(days: 2));
    final data = _LockData(readyAt: base);
    final b = badge.toLowerCase();
    if (b.contains('print') ||
        b.contains('dispatch') ||
        b.contains('deliver')) {
      data.printingAt = base.add(const Duration(hours: 2));
    }
    if (b.contains('dispatch') || b.contains('deliver')) {
      data.dispatchedAt = base.add(const Duration(hours: 4));
    }
    if (b.contains('deliver')) {
      data.deliveredAt = base.add(const Duration(hours: 6));
    }
    _store[id] = data;
  }

  /// Advance the student to the next pipeline stage.
  static void advance(String id) {
    final data = _store[id];
    if (data == null) return;
    final now = DateTime.now();
    if (data.printingAt == null) {
      data.printingAt = now;
    } else if (data.dispatchedAt == null) {
      data.dispatchedAt = now;
    } else if (data.deliveredAt == null) {
      data.deliveredAt = now;
    }
  }

  static void requestReprint(String id) {
    final data = _store[id];
    if (data != null) data.reprintRequested = true;
  }

  static void approveReprint(String id) {
    _store.remove(id);
    _approved.add(id);
  }

  static void rejectReprint(String id) {
    final data = _store[id];
    if (data != null) data.reprintRequested = false;
  }

  static void markApproved(String id) {
    _store.remove(id);
    _approved.add(id);
  }
}

// ═══════════════════════════════════════════════════════════════════
// STUDENT PROFILE
// ═══════════════════════════════════════════════════════════════════

class StudentProfileScreen extends StatefulWidget {
  final String studentId;

  /// Optional fields populated when navigating from pipeline screens.
  final String? studentName;
  final String? studentClass;
  final String? studentRoll;

  /// If provided and student not yet in the lock store, auto-initialises the
  /// pipeline stage from the badge string (e.g. 'Dispatched').
  final String? initialBadge;
  const StudentProfileScreen({
    super.key,
    required this.studentId,
    this.studentName,
    this.studentClass,
    this.studentRoll,
    this.initialBadge,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool get _isLocked => _StudentLockStore.isLocked(widget.studentId);
  _LockData? get _lockData => _StudentLockStore.getData(widget.studentId);
  bool get _isApproved => _StudentLockStore.isApproved(widget.studentId);

  Map<String, dynamic>? _student;

  @override
  void initState() {
    super.initState();
    if (widget.initialBadge != null &&
        !_StudentLockStore.isLocked(widget.studentId)) {
      _StudentLockStore.initFromBadge(widget.studentId, widget.initialBadge!);
    }
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    try {
      final token = await AuthService.instance.getStoredToken();
      final resp = await Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      )).get(
        '/api/students/${widget.studentId}',
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
      final data = resp.data as Map<String, dynamic>;
      // ignore: avoid_print
      print('PROFILE PHOTO URL: ${data['profileImage']}');
      if (mounted) setState(() => _student = data);
    } catch (e) {
      debugPrint('[StudentProfileScreen] failed to load student: $e');
    }
  }

  String get _profileImage =>
      (_student?['profileImage'] as String? ?? '').trim();

  String get _displayName =>
      (_student?['name'] as String? ?? widget.studentName ?? '').trim();
  String get _displaySubtitle {
    final cls =
        (_student?['className'] as String? ?? widget.studentClass ?? '').trim();
    final roll =
        (_student?['rollNumber'] as String? ?? widget.studentRoll ?? '').trim();
    if (cls.isNotEmpty && roll.isNotEmpty) return 'Class $cls  •  Roll $roll';
    if (cls.isNotEmpty) return 'Class $cls';
    if (roll.isNotEmpty) return 'Roll $roll';
    return '';
  }

  bool get _isPrincipal => AuthSession.role == UserRole.principal;

  @override
  Widget build(BuildContext context) {
    final locked = _isLocked;
    final lockData = _lockData;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: _profileImage.isNotEmpty
                                    ? Image.network(
                                        // Cache-bust so re-uploads show immediately
                                        '${ApiConfig.resolveImageUrl(_profileImage)}?t=${DateTime.now().millisecondsSinceEpoch}',
                                        fit: BoxFit.cover,
                                        width: 88,
                                        height: 88,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      )
                                    : const Icon(Icons.person_rounded,
                                        color: Colors.white, size: 48),
                              ),
                            ),
                            if (!locked && !_isApproved)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => context.go(
                                      '/teacher/students/${widget.studentId}/upload-photo'),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.primary, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        size: 15, color: AppColors.primary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName,
                        style: AppTypography.titleLarge
                            .copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _displaySubtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (locked) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Locked',
                                style: AppTypography.labelSmall
                                    .copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            title: const Text('Student Profile'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: (locked || _isApproved)
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => context
                          .go('/teacher/students/${widget.studentId}/edit'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _showDeleteDialog(context),
                    ),
                  ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!locked && !_isApproved) ...[
                  // Action buttons — only when unlocked and not yet approved
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.photo_camera_rounded,
                          label: 'Upload Photo',
                          color: AppColors.primary,
                          onTap: () => context.go(
                              '/teacher/students/${widget.studentId}/upload-photo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _ProfileAction(
                          icon: Icons.lock_rounded,
                          label: 'Verify & Lock',
                          color: AppColors.secondary,
                          onTap: () => _showVerifyDialog(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ] else if (locked) ...[
                  // Printing pipeline — only when locked
                  _PrintingPipelineSection(
                    lockData: lockData!,
                    isPrincipal: _isPrincipal,
                    onRequestCorrection: () =>
                        _onRequestCorrection(context, lockData),
                    onRequestReprint: () => _onRequestReprint(context),
                    onAdvanceStage: () {
                      setState(
                          () => _StudentLockStore.advance(widget.studentId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Stage updated to ${lockData.currentStage.name}',
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onApproveReprint: () {
                      setState(() =>
                          _StudentLockStore.approveReprint(widget.studentId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reprint approved — record reset'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onRejectReprint: () {
                      setState(() =>
                          _StudentLockStore.rejectReprint(widget.studentId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reprint request rejected'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ] else if (_isApproved) ...[
                  // Approved state banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Correction approved — record updated',
                            style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],

                // Info sections (always visible)
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal Info', style: AppTypography.titleSmall),
                      const SizedBox(height: 12),
                      _ProfileRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Date of Birth',
                          value: '15 January 2008'),
                      _ProfileRow(
                          icon: Icons.water_drop_rounded,
                          label: 'Blood Group',
                          value: 'O+'),
                      _ProfileRow(
                          icon: Icons.location_on_rounded,
                          label: 'Address',
                          value: '123, MG Road, Delhi'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parent / Guardian',
                          style: AppTypography.titleSmall),
                      const SizedBox(height: 12),
                      _ProfileRow(
                          icon: Icons.person_rounded,
                          label: 'Parent Name',
                          value: 'Rajesh Kumar'),
                      _PhoneContactRow(phone: '+91 98765 43210'),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.secondary),
            SizedBox(width: 10),
            Text('Verify & Lock'),
          ],
        ),
        content: const Text(
          'Lock this student\'s record? Editing will be disabled and the card will enter the printing pipeline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              setState(() => _StudentLockStore.lock(widget.studentId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Record locked — entered printing pipeline'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Student?'),
        content: const Text(
          'This will permanently remove the student and all their records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.go('/teacher/students');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onRequestCorrection(BuildContext context, _LockData lockData) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _TCorrectionReviewScreen(
        studentId: widget.studentId,
        onApprove: () {
          Navigator.of(context).pop();
          setState(() => _StudentLockStore.markApproved(widget.studentId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Changes approved — record unlocked for editing'),
            ),
          );
        },
        onReject: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Correction request rejected')),
          );
        },
      ),
    ));
  }

  void _onRequestReprint(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Request Reprint'),
          ],
        ),
        content: const Text(
          'Send a reprint request to the principal for this student\'s ID card?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              setState(
                  () => _StudentLockStore.requestReprint(widget.studentId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reprint request sent to principal'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CORRECTION REVIEW SCREEN
// ═══════════════════════════════════════════════════════════════════

class _TCorrectionReviewScreen extends StatelessWidget {
  final String studentId;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TCorrectionReviewScreen({
    required this.studentId,
    required this.onApprove,
    required this.onReject,
  });

  // Dummy current vs requested data
  static const _currentData = {
    'Name': 'Rohit Verma',
    'Class': 'IX-A',
    'Roll No.': '12',
    'DOB': '5 Sep 2009',
    'Blood Group': 'AB+',
    'Phone': '+91 87654 32100',
    'Address': '9 Green Park, Jaipur',
  };

  static const _requestedData = {
    'Name': 'Rohit Kumar Verma',
    'Class': 'IX-A',
    'Roll No.': '12',
    'DOB': '5 Sep 2009',
    'Blood Group': 'AB+',
    'Phone': '+91 87654 00000',
    'Address': '9 Green Park Colony, Jaipur - 302020',
  };

  @override
  Widget build(BuildContext context) {
    final changedKeys = _requestedData.keys
        .where((k) => _requestedData[k] != _currentData[k])
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correction Review'),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.hourglass_top_rounded,
                    size: 14, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Text(
                  'Pending',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Student header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: const Text(
                          'RV',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Rohit Verma',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Class IX-A  •  Roll 12',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B)),
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
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6)),
                          SizedBox(width: 4),
                          Text(
                            'Current Data',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Requested Change',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field rows
                ..._currentData.keys.map((key) {
                  final current = _currentData[key]!;
                  final requested = _requestedData[key]!;
                  final changed = changedKeys.contains(key);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                current,
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Requested
                        Expanded(
                          child: changed
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.25)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        key,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5)),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        requested,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      key,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      requested,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Action buttons pinned at bottom
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Contact row
                Row(
                  children: [
                    Expanded(
                      child: _TContactButton(
                        icon: Icons.sms_rounded,
                        label: 'SMS',
                        color: AppColors.primary,
                        onTap: () async {
                          final uri = Uri.parse('sms:+918765432100');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TContactButton(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: () async {
                          final uri = Uri.parse('https://wa.me/918765432100');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TContactButton(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        color: AppColors.primary,
                        onTap: () async {
                          final uri = Uri.parse('tel:+918765432100');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Reject / Approve row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve Changes',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRINTING PIPELINE TIMELINE
// ═══════════════════════════════════════════════════════════════════

class _PipelineStageInfo {
  final String label;
  final IconData icon;
  final Color color;
  final DateTime? timestamp;

  const _PipelineStageInfo({
    required this.label,
    required this.icon,
    required this.color,
    this.timestamp,
  });
}

class _PrintingPipelineSection extends StatelessWidget {
  final _LockData lockData;
  final bool isPrincipal;
  final VoidCallback onRequestCorrection;
  final VoidCallback onRequestReprint;
  final VoidCallback onAdvanceStage;
  final VoidCallback onApproveReprint;
  final VoidCallback onRejectReprint;

  const _PrintingPipelineSection({
    required this.lockData,
    required this.isPrincipal,
    required this.onRequestCorrection,
    required this.onRequestReprint,
    required this.onAdvanceStage,
    required this.onApproveReprint,
    required this.onRejectReprint,
  });

  String _nextStageLabel(PrintStage stage) => switch (stage) {
        PrintStage.readyToPrint => 'Mark as Printing',
        PrintStage.printing => 'Mark as Dispatched',
        PrintStage.dispatched => 'Mark as Delivered',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final stages = [
      _PipelineStageInfo(
        label: 'Ready to Print',
        icon: Icons.print_rounded,
        color: AppColors.primary,
        timestamp: lockData.readyAt,
      ),
      _PipelineStageInfo(
        label: 'Printing',
        icon: Icons.local_printshop_rounded,
        color: AppColors.warning,
        timestamp: lockData.printingAt,
      ),
      _PipelineStageInfo(
        label: 'Dispatched',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF0891B2),
        timestamp: lockData.dispatchedAt,
      ),
      _PipelineStageInfo(
        label: 'Delivered',
        icon: Icons.inventory_2_rounded,
        color: AppColors.success,
        timestamp: lockData.deliveredAt,
      ),
    ];

    final currentStage = lockData.currentStage;
    final isDelivered = currentStage == PrintStage.delivered;
    final correctionLabel = currentStage == PrintStage.readyToPrint
        ? 'Revert Lock'
        : 'Request Correction';
    final nextLabel = _nextStageLabel(currentStage);
    final reprintPending = lockData.reprintRequested;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_printshop_rounded,
                    size: 16, color: AppColors.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    Text('Printing Pipeline', style: AppTypography.titleSmall),
              ),
              // Current stage badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stages
                      .firstWhere(
                          (s) =>
                              s.timestamp != null &&
                              stages.indexOf(s) ==
                                  stages.lastIndexWhere(
                                      (x) => x.timestamp != null),
                          orElse: () => stages[0])
                      .color
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stages
                      .lastWhere((s) => s.timestamp != null,
                          orElse: () => stages[0])
                      .label,
                  style: AppTypography.caption.copyWith(
                    color: stages
                        .lastWhere((s) => s.timestamp != null,
                            orElse: () => stages[0])
                        .color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Timeline ────────────────────────────────────────────
          ...stages.asMap().entries.map(
                (e) => _PipelineStageRow(
                  stage: e.value,
                  isLast: e.key == stages.length - 1,
                ),
              ),

          // ── Reprint-pending banner (shown to both roles) ─────────
          if (reprintPending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reprint request pending principal approval',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),

          // ── Principal actions ────────────────────────────────────
          if (isPrincipal) ...[
            if (reprintPending) ...[
              // Approve / Reject reprint
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side:
                            BorderSide(color: AppColors.error.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: onRejectReprint,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text('Reject Reprint',
                          style: AppTypography.labelSmall),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: onApproveReprint,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('Approve Reprint',
                          style: AppTypography.labelSmall
                              .copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No pending request — principal can view history / advance
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  minimumSize: const Size(double.infinity, 0),
                ),
                onPressed: onRequestCorrection,
                icon: const Icon(Icons.history_rounded, size: 16),
                label: Text('View Request History',
                    style: AppTypography.labelSmall),
              ),
            ],
          ]
          // ── Teacher actions ──────────────────────────────────────
          else ...[
            // Advance stage button (hidden once delivered or reprint pending)
            if (!isDelivered && !reprintPending && nextLabel.isNotEmpty) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  minimumSize: const Size(double.infinity, 0),
                ),
                onPressed: onAdvanceStage,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(nextLabel,
                    style:
                        AppTypography.labelSmall.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side:
                          BorderSide(color: AppColors.warning.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: onRequestCorrection,
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label:
                        Text(correctionLabel, style: AppTypography.labelSmall),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: reprintPending
                          ? AppColors.warning
                          : AppColors.primary,
                      side: BorderSide(
                          color: (reprintPending
                                  ? AppColors.warning
                                  : AppColors.primary)
                              .withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: reprintPending ? null : onRequestReprint,
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text(
                      reprintPending ? 'Request Pending' : 'Request Reprint',
                      style: AppTypography.labelSmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PipelineStageRow extends StatelessWidget {
  final _PipelineStageInfo stage;
  final bool isLast;

  const _PipelineStageRow({required this.stage, required this.isLast});

  String _fmt(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }

  @override
  Widget build(BuildContext context) {
    final reached = stage.timestamp != null;
    final activeColor = reached
        ? stage.color
        : Theme.of(context).colorScheme.outline.withOpacity(0.35);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: reached
                        ? stage.color.withOpacity(0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeColor,
                      width: reached ? 2 : 1.5,
                    ),
                  ),
                  child: Icon(stage.icon, size: 13, color: activeColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: activeColor.withOpacity(0.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.label,
                    style: AppTypography.labelMedium.copyWith(
                      color: reached
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                      fontWeight: reached ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reached ? _fmt(stage.timestamp!) : 'Pending',
                    style: AppTypography.caption.copyWith(
                      color: reached
                          ? stage.color
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProfileAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
                Text(value, style: AppTypography.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact circle button ────────────────────────────────────────
/// Circular gradient button used in the Parent / Guardian contact row.
class _ContactCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ContactCircleButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone row that shows the number plus Call / WhatsApp / Messenger icons.
class _PhoneContactRow extends StatelessWidget {
  final String phone;
  const _PhoneContactRow({required this.phone});

  /// Strip all non-digit characters (keeps leading digits including country code).
  String get _digits => phone.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_rounded,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
                Text(phone, style: AppTypography.labelMedium),
              ],
            ),
          ),
          // ── Action icons ──────────────────────────────────────────
          _ContactCircleButton(
            icon: Icons.call_rounded,
            label: 'Call',
            onTap: () async {
              final uri = Uri.parse('tel:+$_digits');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
          const SizedBox(width: 10),
          _ContactCircleButton(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            onTap: () async {
              final uri = Uri.parse('https://wa.me/$_digits');
              if (await canLaunchUrl(uri)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(width: 10),
          _ContactCircleButton(
            icon: Icons.message_rounded,
            label: 'Messenger',
            onTap: () async {
              final mesUri = Uri.parse('https://m.me/');
              if (await canLaunchUrl(mesUri)) {
                launchUrl(mesUri, mode: LaunchMode.externalApplication);
              } else {
                final smsUri = Uri.parse('sms:+$_digits');
                if (await canLaunchUrl(smsUri)) launchUrl(smsUri);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EDIT STUDENT
// ═══════════════════════════════════════════════════════════════════
class EditStudentScreen extends StatelessWidget {
  final String studentId;
  const EditStudentScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Student'),
        actions: [
          TextButton(
            onPressed: () => _showSaveConfirmation(context),
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Photo
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded,
                        size: 48, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => context
                          .go('/teacher/students/$studentId/upload-photo'),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const AppTextField(label: 'Full Name', hint: 'Enter full name'),
            const SizedBox(height: 16),
            const AppTextField(label: 'Roll Number', hint: 'Enter roll number'),
            const SizedBox(height: 16),
            const AppTextField(label: 'Class', hint: 'e.g. X'),
            const SizedBox(height: 16),
            const AppTextField(label: 'Section', hint: 'e.g. A'),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Date of Birth',
              hint: 'DD/MM/YYYY',
              prefixIcon: Icon(Icons.calendar_month_rounded, size: 20),
            ),
            const SizedBox(height: 16),
            const AppTextField(label: 'Blood Group', hint: 'e.g. O+'),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Address',
              hint: 'Enter address',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const AppTextField(label: 'Parent Name', hint: 'Enter parent name'),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Parent Phone',
              hint: 'Enter parent phone',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Save Changes',
              onTap: () => _showSaveConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Save Changes?'),
        content: const Text(
          'Are you sure you want to save the changes to this student\'s profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Student data saved successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// UPLOAD PHOTO
// ═══════════════════════════════════════════════════════════════════
class UploadPhotoScreen extends StatelessWidget {
  final String studentId;
  const UploadPhotoScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Photo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Photo Source', style: AppTypography.titleSmall),
            const SizedBox(height: 20),
            _SourceCard(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              subtitle: 'Use camera to capture student photo',
              color: AppColors.primary,
              onTap: () => context
                  .go('/teacher/students/$studentId/upload-photo/camera'),
            ),
            const SizedBox(height: 12),
            _SourceCard(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              subtitle: 'Select from device gallery',
              color: AppColors.secondary,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _SourceCard(
              icon: Icons.cloud_upload_rounded,
              label: 'Upload from Files',
              subtitle: 'Browse and select a photo file',
              color: AppColors.accent,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SourceCard(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelLarge),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CAMERA CAPTURE
// ═══════════════════════════════════════════════════════════════════
class CameraCaptureScreen extends StatelessWidget {
  final String studentId;
  const CameraCaptureScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview placeholder
          Container(color: Colors.black87),

          // Face guide overlay
          Center(
            child: Container(
              width: 240,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(120),
              ),
              child: const Center(
                child:
                    Icon(Icons.face_rounded, color: Colors.white24, size: 80),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Text(
                    'Align face within the guide',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                    // Shutter button
                    GestureDetector(
                      onTap: () => context
                          .go('/teacher/students/$studentId/upload-photo/crop'),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 4),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_rounded,
                              color: Colors.black, size: 32),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_android_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CROP PHOTO
// ═══════════════════════════════════════════════════════════════════
class CropPhotoScreen extends StatelessWidget {
  final String studentId;
  const CropPhotoScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo uploaded successfully!')),
              );
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey[800],
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white24, size: 120),
                  ),
                  // Crop overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                                width: 20, height: 3, color: Colors.white),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                                width: 3, height: 20, color: Colors.white),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                                width: 20, height: 3, color: Colors.white),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                                width: 3, height: 20, color: Colors.white),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                                width: 20, height: 3, color: Colors.white),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                                width: 3, height: 20, color: Colors.white),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                                width: 20, height: 3, color: Colors.white),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                                width: 3, height: 20, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Controls
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CropControl(
                    icon: Icons.rotate_left_rounded, label: 'Rotate L'),
                _CropControl(
                    icon: Icons.rotate_right_rounded, label: 'Rotate R'),
                _CropControl(icon: Icons.flip_rounded, label: 'Flip'),
                _CropControl(icon: Icons.crop_square_rounded, label: '1:1'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CropControl extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CropControl({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA VERIFICATION + SEND CORRECTION (combined)
// ═══════════════════════════════════════════════════════════════════
class DataVerificationScreen extends StatefulWidget {
  final String studentId;
  const DataVerificationScreen({super.key, required this.studentId});
  @override
  State<DataVerificationScreen> createState() => _DataVerificationScreenState();
}

// Keep alias so existing router reference to SendCorrectionScreen still compiles
typedef SendCorrectionScreen = DataVerificationScreen;

class _DataVerificationScreenState extends State<DataVerificationScreen> {
  final Map<String, bool> _checks = {
    'Name is correct': false,
    'Date of birth matches records': false,
    'Class and section verified': false,
    'Photo is clear and recent': false,
    'Parent info is accurate': false,
    'Address is complete': false,
  };

  final List<String> _selectedFields = [];
  final _noteCtrl = TextEditingController();
  bool _isSending = false;

  Map<String, String> get _studentInfo =>
      CorrectionsRepository.instance.studentData(widget.studentId) ??
      {'Name': 'Unknown Student', 'Class': '—', 'Roll No.': '—'};

  static const _correctionFields = [
    'Name',
    'Date of Birth',
    'Class/Section',
    'Photo',
    'Parent Name',
    'Parent Phone',
    'Address',
    'Blood Group',
  ];

  bool get _allVerified => _checks.values.every((v) => v);

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify & Lock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student card ───────────────────────────────────────
            PremiumCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studentInfo['Name'] ?? 'Unknown Student',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Class ${_studentInfo['Class'] ?? '—'}  •  Roll ${_studentInfo['Roll No.'] ?? '—'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Verification Checklist ─────────────────────────────
            Text('Verification Checklist', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            ..._checks.keys.map(
              (key) => CheckboxListTile(
                title: Text(key, style: AppTypography.bodyMedium),
                value: _checks[key],
                activeColor: AppColors.success,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _checks[key] = v ?? false),
              ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _allVerified
                  ? GradientButton(
                      key: const ValueKey('verified'),
                      label: 'Mark as Verified',
                      prefixIcon: Icons.verified_rounded,
                      gradient: const LinearGradient(
                        colors: [AppColors.success, AppColors.secondary],
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Student data verified successfully!')),
                        );
                        context.pop();
                      },
                    )
                  : Container(
                      key: const ValueKey('pending'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_rounded,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Complete all checks to verify',
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),

            // ── Send Correction Request ────────────────────────────
            Text('Send Correction Request', style: AppTypography.titleSmall),
            const SizedBox(height: 6),
            Text('Select fields that need correction:',
                style: AppTypography.labelLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _correctionFields
                  .map(
                    (f) => FilterChip(
                      label: Text(f),
                      selected: _selectedFields.contains(f),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedFields.add(f);
                        } else {
                          _selectedFields.remove(f);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Note to Parent / Student',
              hint: 'Add instructions or context...',
              controller: _noteCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Send Correction Request',
              isLoading: _isSending,
              prefixIcon: Icons.send_rounded,
              onTap: _selectedFields.isEmpty
                  ? null
                  : () async {
                      setState(() => _isSending = true);
                      await Future.delayed(const Duration(seconds: 2));
                      setState(() => _isSending = false);
                      if (context.mounted) {
                        context.go(
                            '/teacher/students/${widget.studentId}/correction-success');
                      }
                    },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CORRECTION SUCCESS
// ═══════════════════════════════════════════════════════════════════
class CorrectionSuccessScreen extends StatelessWidget {
  const CorrectionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 56),
                ).animate().fadeIn().scale(begin: const Offset(0.5, 0.5)),
                const SizedBox(height: 24),
                Text('Request Sent!', style: AppTypography.headlineSmall)
                    .animate()
                    .fadeIn(delay: 300.ms),
                const SizedBox(height: 8),
                Text(
                  'The correction request has been sent to the parent/student via SMS and email.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 40),
                PrimaryButton(
                  label: 'Back to Student Profile',
                  onTap: () => context.go('/teacher/students'),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/teacher'),
                  child: const Text('Go to Dashboard'),
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TEACHER SHELL  ─  Home | Data | Add(center FAB) | Attendance | Profile
// ═══════════════════════════════════════════════════════════════════

class TeacherShell extends StatelessWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  static const _purple = AppColors.primary;

  int _activeTab(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/teacher/data')) return 1;
    if (path.startsWith('/teacher/attendance')) return 3;
    if (path.startsWith('/teacher/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tab = _activeTab(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!nav.canPop()) await LogoutHelper.logout(context);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: _TeacherBottomNav(
          activeTab: tab,
          isDark: isDark,
          purple: _purple,
          onTap: (i) => _handleTap(i, context),
        ),
      ),
    );
  }

  void _handleTap(int i, BuildContext context) {
    switch (i) {
      case 0:
        context.go('/teacher');
      case 1:
        context.go('/teacher/data');
      case 2:
        _showAddSheet(context);
      case 3:
        context.go('/teacher/attendance');
      case 4:
        context.go('/teacher/profile');
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _TeacherAddBottomSheet(),
    );
  }
}

// ── Bottom Nav ──────────────────────────────────────────────────────

class _TeacherBottomNav extends StatelessWidget {
  final int activeTab;
  final bool isDark;
  final Color purple;
  final ValueChanged<int> onTap;
  const _TeacherBottomNav({
    required this.activeTab,
    required this.isDark,
    required this.purple,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surface1Dark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final items = [
      _TNavDef('Home', Icons.home_outlined, Icons.home_rounded),
      _TNavDef('Data', Icons.analytics_outlined, Icons.analytics_rounded),
      _TNavDef('Add', Icons.add_rounded, Icons.add_rounded),
      _TNavDef(
          'Attendance', Icons.fact_check_outlined, Icons.fact_check_rounded),
      _TNavDef('Profile', Icons.person_outlined, Icons.person_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: List.generate(items.length, (i) {
                  if (i == 2) return const Expanded(child: SizedBox());
                  final def = items[i];
                  final sel = activeTab == i;
                  final color = sel
                      ? purple
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45);
                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              sel ? def.activeIcon : def.icon,
                              key: ValueKey(sel),
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            def.label,
                            style: AppTypography.caption.copyWith(
                              color: color,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              // Centered elevated FAB
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: GestureDetector(
                      onTap: () => onTap(2),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [purple, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: purple.withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TNavDef {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TNavDef(this.label, this.icon, this.activeIcon);
}

// ── Teacher Add Bottom Sheet ──────────────────────────────────────

class _TeacherAddBottomSheet extends StatelessWidget {
  const _TeacherAddBottomSheet();

  void _showForm(BuildContext rootCtx, Widget form) {
    Navigator.of(rootCtx).pop();
    showModalBottomSheet(
      context: rootCtx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => form,
    );
  }

  @override
  Widget build(BuildContext context) {
    final opts = [
      (
        Icons.school_rounded,
        'Add Student',
        'Enroll a new student to your class',
        AppColors.primary,
        () => _showForm(context, const _TAddStudentSheet()),
      ),
      (
        Icons.event_note_rounded,
        'Add Notice',
        'Post a notice for students',
        AppColors.accent,
        () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateNoticeScreen(),
            ),
          );
        },
      ),
    ];

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quick Add', style: AppTypography.titleMedium),
                Text(
                  'What would you like to create?',
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 20),
            ...opts.asMap().entries.map((e) {
              final (icon, label, sub, color, onTap) = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.18)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: AppTypography.labelLarge),
                            Text(
                              sub,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: color.withOpacity(0.6)),
                    ]),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 40 * e.key))
                    .fadeIn(duration: 200.ms)
                    .slideX(begin: 0.05, end: 0),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Mini form sheets (placeholder UI, ready to expand)
class _TAddStudentSheet extends StatefulWidget {
  const _TAddStudentSheet();
  @override
  State<_TAddStudentSheet> createState() => _TAddStudentSheetState();
}

class _TAddStudentSheetState extends State<_TAddStudentSheet> {
  final _nameCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _classSectionCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _bloodGroup = 'O+';
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    _classSectionCtrl.dispose();
    _dobCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2009),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Add Student', style: AppTypography.titleMedium),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _rollCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Roll Number',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _classSectionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Class / Section',
                    hintText: 'e.g. X-A',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _dobCtrl,
              readOnly: true,
              onTap: _pickDob,
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'DD/MM/YYYY',
                prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _bloodGroup,
              decoration: InputDecoration(
                labelText: 'Blood Group',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _bloodGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodGroup = v ?? 'O+'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _parentNameCtrl,
              decoration: InputDecoration(
                labelText: 'Parent / Guardian Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _parentPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Parent Phone',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Address',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student added successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Add Student'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _TAddNoticeSheet replaced by CreateNoticeScreen (see notice_screens.dart)

// ═══════════════════════════════════════════════════════════════════
// TEACHER DATA SCREEN
// ═══════════════════════════════════════════════════════════════════

class TeacherDataScreen extends StatefulWidget {
  const TeacherDataScreen({super.key});

  @override
  State<TeacherDataScreen> createState() => _TeacherDataScreenState();
}

class _TeacherDataScreenState extends State<TeacherDataScreen> {
  static const _purple = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _TeacherDataStore.instance.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _TeacherDataStore.instance,
      builder: (context, _) {
        final store = _TeacherDataStore.instance;
        final sections = [
          _TSectionDef(
            icon: Icons.class_,
            title: 'My Classes',
            count: '${store.classCount}',
            unit: 'classes',
            subtitle: '${store.studentCount} total students',
            color: AppColors.secondary,
          ),
          _TSectionDef(
            icon: Icons.school_rounded,
            title: 'Students',
            count: '${store.studentCount}',
            unit: 'students',
            subtitle: 'Enrolled students',
            color: AppColors.primary,
          ),
          _TSectionDef(
            icon: Icons.person_rounded,
            title: 'Teachers',
            count: '${store.teacherCount}',
            unit: 'teachers',
            subtitle: 'School faculty',
            color: _purple,
          ),
          _TSectionDef(
            icon: Icons.badge_rounded,
            title: 'Staff',
            count: '${store.staffCount}',
            unit: 'staff',
            subtitle: 'Non-teaching staff',
            color: AppColors.accent,
          ),
        ];

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                title: const Text('Class Data'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    onPressed: () =>
                        _TeacherDataStore.instance.loadAll(force: true),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TeacherHeaderCard(purple: _purple, store: store)
                        .animate()
                        .fadeIn(duration: 300.ms),
                    const SizedBox(height: 24),
                    if (store.isLoading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ))
                    else ...[
                      Row(children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _purple,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Data Sections',
                            style: AppTypography.titleSmall
                                .copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 14),
                      ...sections.asMap().entries.map((e) {
                        final s = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TDataSectionCard(
                            def: s,
                            onTap: () {
                              if (s.title == 'My Classes') {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const _TClassListScreen(),
                                ));
                              } else {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => _TDataSectionScreen(
                                    title: s.title,
                                    icon: s.icon,
                                    color: s.color,
                                  ),
                                ));
                              }
                            },
                          )
                              .animate(
                                  delay: Duration(milliseconds: 80 * e.key))
                              .fadeIn(duration: 250.ms)
                              .slideX(begin: 0.04, end: 0),
                        );
                      }),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TSectionDef {
  final IconData icon;
  final String title;
  final String count;
  final String unit;
  final String subtitle;
  final Color color;
  const _TSectionDef({
    required this.icon,
    required this.title,
    required this.count,
    required this.unit,
    required this.subtitle,
    required this.color,
  });
}

class _TeacherHeaderCard extends StatelessWidget {
  final Color purple;
  final _TeacherDataStore store;
  const _TeacherHeaderCard({required this.purple, required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [purple, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: purple.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              const Icon(Icons.person_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Priya Nair',
                style: AppTypography.titleSmall.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Class Teacher · Grade 8',
                style: AppTypography.bodySmall
                    .copyWith(color: Colors.white.withOpacity(0.75))),
            const SizedBox(height: 10),
            Row(children: [
              _TChip('${store.studentCount}', 'Students', Colors.white),
              const SizedBox(width: 16),
              _TChip('${store.classCount}', 'Classes', Colors.white),
              const SizedBox(width: 16),
              _TChip('${store.teacherCount}', 'Teachers',
                  Colors.white.withOpacity(0.8)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TChip extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _TChip(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val,
            style: AppTypography.labelLarge
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        Text(lbl,
            style: AppTypography.caption.copyWith(color: col.withOpacity(0.8))),
      ]);
}

class _TDataSectionCard extends StatelessWidget {
  final _TSectionDef def;
  final VoidCallback onTap;
  const _TDataSectionCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: def.color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: def.color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: def.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(def.icon, color: def.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.title,
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(def.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: def.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              def.count,
              style: AppTypography.titleSmall
                  .copyWith(color: def.color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: def.color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CLASS PROMOTION HELPER  (teacher)
// ═══════════════════════════════════════════════════════════════════

/// Shows confirmation and promotes a class via the backend.
/// Uses the same promote-class endpoint as the principal flow.
Future<void> _showTeacherPromoteDialog(
    BuildContext context, String className) async {
  final sm = ScaffoldMessenger.of(context);

  final match = RegExp(r'^(\d+)(.*)$').firstMatch(className.trim());
  if (match == null) {
    sm.showSnackBar(SnackBar(
      content: Text(
          '"$className" cannot be auto-promoted — name must start with a number (e.g. "1 - A")'),
    ));
    return;
  }

  final nextNum = int.parse(match.group(1)!) + 1;
  final nextName = '$nextNum${match.group(2)!}';

  if (nextNum > 12) {
    sm.showSnackBar(SnackBar(
      content:
          Text('"$className" is already at class 12 — cannot promote further.'),
    ));
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.trending_up_rounded, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text('Promote Class'),
      ]),
      content: Text(
        'Move all students from\n'
        '"$className"  →  "$nextName"\n\n'
        'If "$nextName" does not exist it will be created automatically.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.trending_up_rounded, size: 18),
          label: const Text('Promote'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  sm.showSnackBar(SnackBar(
    content: Row(children: [
      const SizedBox(
          width: 18,
          height: 18,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      const SizedBox(width: 12),
      Text('Promoting "$className" → "$nextName"…'),
    ]),
    duration: const Duration(seconds: 20),
  ));

  try {
    final res = await _schoolDio().post(
      ApiConfig.principalPromoteClass,
      data: {'className': className, 'principalId': _kSchoolPrincipalId},
    );
    sm.hideCurrentSnackBar();

    if (res.statusCode == 200) {
      final count =
          (res.data as Map?)?.cast<String, dynamic>()['studentsPromoted'] ?? 0;
      sm.showSnackBar(SnackBar(
        content: Text('✓ Promoted to "$nextName" — $count student(s) moved.'),
        backgroundColor: AppColors.success,
      ));
      _TeacherDataStore.instance.loadAll(force: true);
    } else {
      final msg = ((res.data as Map?)?.cast<String, dynamic>()['error']) ??
          'Failed to promote class';
      sm.showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (e) {
    sm.hideCurrentSnackBar();
    sm.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

// ═══════════════════════════════════════════════════════════════════
// T CLASS LIST SCREEN
// ═══════════════════════════════════════════════════════════════════

class _TClassInfo {
  final String name;
  final int total;
  final Color color;
  const _TClassInfo({
    required this.name,
    required this.total,
    required this.color,
  });
}

class _TClassListScreen extends StatefulWidget {
  const _TClassListScreen();

  @override
  State<_TClassListScreen> createState() => _TClassListScreenState();
}

class _TClassListScreenState extends State<_TClassListScreen> {
  static const _purple = AppColors.primary;
  static const _palette = [
    AppColors.secondary,
    AppColors.primary,
    AppColors.accent,
    AppColors.roleTeacher,
  ];

  @override
  void initState() {
    super.initState();
    _TeacherDataStore.instance.loadAll();
    _TeacherDataStore.instance.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _TeacherDataStore.instance.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _TeacherDataStore.instance;
    final classes = store.classes
        .asMap()
        .entries
        .map((e) => _TClassInfo(
              name: e.value['name'] as String? ?? '',
              total: store
                  .studentsForClass(e.value['name'] as String? ?? '')
                  .length,
              color: _palette[e.key % _palette.length],
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? const Center(child: Text('No classes added yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final c = classes[i];
                    return InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _TClassDetailScreen(classInfo: c),
                      )),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: c.color.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: c.color.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.class_, color: c.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: AppTypography.labelLarge
                                        .copyWith(fontWeight: FontWeight.w700)),
                                Text('${c.total} students',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5))),
                              ],
                            ),
                          ),
                          // ── Promote button ──────────────────────
                          Tooltip(
                            message: 'Promote to next class',
                            child: InkWell(
                              onTap: () =>
                                  _showTeacherPromoteDialog(context, c.name),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: c.color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.trending_up_rounded,
                                  size: 20,
                                  color: c.color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded,
                              color: c.color.withOpacity(0.6)),
                        ]),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 50 * i))
                        .fadeIn(duration: 200.ms);
                  },
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// T CLASS DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════

class _TClassDetailScreen extends StatelessWidget {
  final _TClassInfo classInfo;
  const _TClassDetailScreen({required this.classInfo});

  @override
  Widget build(BuildContext context) {
    final students =
        _TeacherDataStore.instance.studentsForClass(classInfo.name);
    return Scaffold(
      appBar: AppBar(
        title: Text(classInfo.name),
        backgroundColor: classInfo.color,
        foregroundColor: Colors.white,
      ),
      body: students.isEmpty
          ? const Center(child: Text('No students in this class yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = students[i];
                final name = s['name'] as String? ?? '';
                final dept = s['classOrDept'] as String? ?? '';
                final phone = s['phone'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: classInfo.color.withOpacity(0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTypography.labelMedium
                          .copyWith(color: classInfo.color),
                    ),
                  ),
                  title: Text(name, style: AppTypography.labelLarge),
                  subtitle: Text(
                    dept.isEmpty ? (phone.isEmpty ? '' : phone) : dept,
                    style: AppTypography.caption,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: classInfo.color.withOpacity(0.5)),
                ).animate(delay: Duration(milliseconds: 20 * i)).fadeIn();
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// T DATA SECTION SCREEN (Students / Teachers / Staff)
// ═══════════════════════════════════════════════════════════════════

class _TDataSectionScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _TDataSectionScreen({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  State<_TDataSectionScreen> createState() => _TDataSectionScreenState();
}

class _TDataSectionScreenState extends State<_TDataSectionScreen> {
  @override
  void initState() {
    super.initState();
    _TeacherDataStore.instance.loadAll();
    _TeacherDataStore.instance.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _TeacherDataStore.instance.removeListener(_update);
    super.dispose();
  }

  List<Map<String, dynamic>> get _members {
    final store = _TeacherDataStore.instance;
    if (widget.title == 'Teachers') return store.teachers;
    if (widget.title == 'Staff') return store.staff;
    return store.students;
  }

  @override
  Widget build(BuildContext context) {
    final store = _TeacherDataStore.instance;
    final members = _members;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
              ? Center(
                  child: Text('No ${widget.title.toLowerCase()} added yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final name = m['name'] as String? ?? '';
                    final dept = m['classOrDept'] as String? ?? '';
                    final phone = m['phone'] as String? ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: widget.color.withOpacity(0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTypography.labelMedium
                              .copyWith(color: widget.color),
                        ),
                      ),
                      title: Text(name, style: AppTypography.labelLarge),
                      subtitle: Text(
                        [if (dept.isNotEmpty) dept, if (phone.isNotEmpty) phone]
                            .join('  ·  '),
                        style: AppTypography.caption,
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: widget.color.withOpacity(0.5)),
                    ).animate(delay: Duration(milliseconds: 20 * i)).fadeIn();
                  },
                ),
    );
  }
}

// ─── Filtered Member List (Teacher Side) ─────────────────────────────────────

class _TFilteredMemberListScreen extends StatefulWidget {
  final String category;
  final String section;
  final IconData icon;
  final Color color;
  const _TFilteredMemberListScreen({
    required this.category,
    required this.section,
    required this.icon,
    required this.color,
  });

  @override
  State<_TFilteredMemberListScreen> createState() =>
      _TFilteredMemberListScreenState();
}

class _TFilteredMemberListScreenState
    extends State<_TFilteredMemberListScreen> {
  @override
  void initState() {
    super.initState();
    _TeacherDataStore.instance.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _TeacherDataStore.instance.removeListener(_update);
    super.dispose();
  }

  List<Map<String, dynamic>> get _items {
    final store = _TeacherDataStore.instance;
    final sec = widget.section.toLowerCase();
    if (sec == 'teachers') return store.teachers;
    if (sec == 'staff') return store.staff;
    if (sec == 'students') return store.students;
    // class-specific
    return store.studentsForClass(widget.section);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon,
                      size: 64, color: widget.color.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No records found',
                      style: AppTypography.titleSmall
                          .copyWith(color: widget.color.withOpacity(0.6))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = items[i];
                final name = m['name'] as String? ?? '';
                final dept = m['classOrDept'] as String? ?? '';
                final phone = m['phone'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.color.withOpacity(0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTypography.labelSmall
                          .copyWith(color: widget.color),
                    ),
                  ),
                  title: Text(name, style: AppTypography.labelLarge),
                  subtitle: Text(
                    [if (dept.isNotEmpty) dept, if (phone.isNotEmpty) phone]
                        .join('  ·  '),
                    style: AppTypography.caption,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: widget.color.withOpacity(0.5)),
                ).animate(delay: Duration(milliseconds: 20 * i)).fadeIn();
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TEACHER ATTENDANCE SCREEN
// ═══════════════════════════════════════════════════════════════════

class TeacherAttendanceScreen extends StatelessWidget {
  const TeacherAttendanceScreen({super.key});

  static const _green = AppColors.success;
  static const _classNames = [
    'Class 8A',
    'Class 8B',
    'Class 9A',
    'Class 9B',
  ];
  static const _totals = [42, 40, 45, 38];
  static const _present = [40, 38, 44, 36];

  static String _wd(int d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  static String _mn(int m) => const [
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
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${_wd(now.weekday)}, ${now.day} ${_mn(now.month)} ${now.year}';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            title: const Text('Attendance'),
          ),
          SliverToBoxAdapter(
            child: _TAttHeader(green: _green, dateLabel: dateLabel)
                .animate()
                .fadeIn(duration: 300.ms),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = _present[i];
                  final t = _totals[i];
                  final pct = (p / t * 100).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _TClassAttendanceScreen(
                            className: _classNames[i],
                            total: t,
                            presentToday: p,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: _green.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: AppTypography.titleMedium.copyWith(
                                      color: _green,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_classNames[i],
                                    style: AppTypography.labelLarge
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: p / t,
                                    color: _green,
                                    backgroundColor: _green.withOpacity(0.1),
                                    minHeight: 5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('$p / $t present',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$pct%',
                                style: AppTypography.labelSmall.copyWith(
                                    color: _green,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              color: _green.withOpacity(0.5)),
                        ]),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 50 * i))
                        .fadeIn(duration: 200.ms)
                        .slideX(begin: 0.04, end: 0),
                  );
                },
                childCount: _classNames.length,
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _TAttHeader extends StatelessWidget {
  final Color green;
  final String dateLabel;
  const _TAttHeader({required this.green, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [green, const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              const Icon(Icons.person_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Priya Nair · Teacher',
                style: AppTypography.titleSmall.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(dateLabel,
                style: AppTypography.bodySmall
                    .copyWith(color: Colors.white.withOpacity(0.75))),
            const SizedBox(height: 10),
            Row(children: [
              _TAttChip('165', 'Total', Colors.white),
              const SizedBox(width: 16),
              _TAttChip('158', 'Present', Colors.white),
              const SizedBox(width: 16),
              _TAttChip('7', 'Absent', Colors.white.withOpacity(0.75)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TAttChip extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _TAttChip(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val,
            style: AppTypography.labelLarge
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        Text(lbl,
            style: AppTypography.caption.copyWith(color: col.withOpacity(0.8))),
      ]);
}

// ── Class Attendance Screen (3 action cards) ─────────────────────

class _TClassAttendanceScreen extends StatelessWidget {
  final String className;
  final int total;
  final int presentToday;
  const _TClassAttendanceScreen({
    required this.className,
    required this.total,
    required this.presentToday,
  });

  static const _green = AppColors.success;

  @override
  Widget build(BuildContext context) {
    final absent = total - presentToday;
    final pct = (presentToday / total * 100).toInt();

    final actions = [
      (
        Icons.qr_code_scanner_rounded,
        'QR Scanner',
        'Scan QR code on student ID card',
        AppColors.primary,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _TScannerAttendanceScreen(className: className),
            )),
      ),
      (
        Icons.checklist_rounded,
        'Manual Attendance',
        'Mark attendance from the student list',
        _green,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  _TManualAttendanceScreen(className: className, total: total),
            )),
      ),
      (
        Icons.history_rounded,
        'View Attendance',
        'Browse historical attendance records',
        AppColors.accent,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _TViewAttendanceScreen(className: className),
            )),
      ),
      (
        Icons.bar_chart_rounded,
        'Attendance Report',
        'Generate individual or class attendance report with PDF export',
        AppColors.primary,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TAttendanceReportScreen(
                className: className,
                total: total,
              ),
            )),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _green.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TAStat('$total', 'Total', Colors.white),
                _TAStat('$presentToday', 'Present', Colors.white),
                _TAStat('$absent', 'Absent', Colors.white.withOpacity(0.8)),
                _TAStat('$pct%', 'Rate', Colors.white),
              ],
            ),
          ).animate().fadeIn(duration: 280.ms),
          const SizedBox(height: 28),
          Row(children: [
            Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Quick Actions',
                style: AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...actions.asMap().entries.map((e) {
            final (icon, title, sub, color, onTap) = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withOpacity(0.22), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: color, size: 30),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppTypography.titleSmall
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(sub,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              )),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: color, size: 18),
                    ),
                  ]),
                ),
              )
                  .animate(delay: Duration(milliseconds: 80 * e.key))
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.06, end: 0),
            );
          }),
        ],
      ),
    );
  }
}

class _TAStat extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _TAStat(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: AppTypography.titleSmall
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(lbl,
            style: AppTypography.caption.copyWith(color: col.withOpacity(0.8))),
      ]);
}

// ── Scanner Attendance ────────────────────────────────────────────

class _TScannerAttendanceScreen extends StatefulWidget {
  final String className;
  const _TScannerAttendanceScreen({required this.className});
  @override
  State<_TScannerAttendanceScreen> createState() =>
      _TScannerAttendanceScreenState();
}

class _TScannerAttendanceScreenState extends State<_TScannerAttendanceScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  String? _lastCode;
  int _scannedCount = 0;

  // (name, roll, parentPhone)
  static const _mockStudents = {
    'STU001': ('Aarav Sharma', 'Roll 01', '9876543210'),
    'STU002': ('Priya Verma', 'Roll 02', '9123456780'),
    'STU003': ('Rohan Singh', 'Roll 03', '9988776655'),
    'STU004': ('Sneha Gupta', 'Roll 04', '9871234560'),
    'STU005': ('Karan Mehta', 'Roll 05', '9765432100'),
    'STU006': ('Divya Joshi', 'Roll 06', '9654321098'),
    'STU007': ('Amit Patel', 'Roll 07', '9543210987'),
    'STU008': ('Neha Sharma', 'Roll 08', '9432109876'),
    'STU009': ('Rahul Mishra', 'Roll 09', '9321098765'),
    'STU010': ('Anjali Yadav', 'Roll 10', '9210987654'),
  };

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastCode) return;
    setState(() {
      _lastCode = code;
      _scannedCount++;
    });
    _openList(scannedCode: code);
  }

  void _openList({String? scannedCode}) {
    final code = scannedCode ?? 'STU001';
    final student = _mockStudents[code];
    _scanner.stop();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => _TQRScanResultScreen(
        className: widget.className,
        scannedCode: code,
        studentName: student?.$1 ?? 'Unknown Student',
        rollLabel: student?.$2 ?? 'Scanned ID',
        phone: student?.$3 ?? '',
        allStudents: _mockStudents,
      ),
    ))
        .then((_) {
      if (mounted) _scanner.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('QR Scanner — ${widget.className}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.flash_on_rounded),
              onPressed: _scanner.toggleTorch),
          IconButton(
              icon: const Icon(Icons.cameraswitch_rounded),
              onPressed: _scanner.switchCamera),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _scanner, onDetect: _onDetect),
        // scan frame
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border:
                  Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(children: [
              Positioned(top: 0, left: 0, child: _TScanCorner(topLeft: true)),
              Positioned(top: 0, right: 0, child: _TScanCorner(topRight: true)),
              Positioned(
                  bottom: 0, left: 0, child: _TScanCorner(bottomLeft: true)),
              Positioned(
                  bottom: 0, right: 0, child: _TScanCorner(bottomRight: true)),
            ]),
          ),
        ),
        // hint text above button area
        Positioned(
          bottom: 110,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Align the student ID QR code within the frame',
                style: AppTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        // scanned counter badge
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_scannedCount Scanned',
              style: AppTypography.labelSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
        // View Student List button
        Positioned(
          bottom: 36,
          left: 40,
          right: 40,
          child: GestureDetector(
            onTap: () => _openList(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_alt_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'View Student List',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (_scannedCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_scannedCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── QR Scan Result ────────────────────────────────────────────────

class _TQRScanResultScreen extends StatelessWidget {
  final String className;
  final String scannedCode;
  final String studentName;
  final String rollLabel;
  final String phone;
  final Map<String, (String, String, String)> allStudents;

  const _TQRScanResultScreen({
    required this.className,
    required this.scannedCode,
    required this.studentName,
    required this.rollLabel,
    required this.phone,
    required this.allStudents,
  });

  static const _green = AppColors.success;
  static const _whatsappGreen = Color(0xFF25D366);
  static const _smsBlue = AppColors.primary;
  static const _callPurple = AppColors.primary;

  Future<void> _launch(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this action')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('QR Scanner — $className'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // ── Scanned student banner ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: _green, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        rollLabel,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Present',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),

          // ── Section label ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.people_rounded,
                    size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Class Students — $className',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // ── Student list ──
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: allStudents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = allStudents.entries.elementAt(index);
                final isScanned = entry.key == scannedCode;
                final s = entry.value;
                return _TQRStudentTile(
                  name: s.$1,
                  roll: s.$2,
                  phone: s.$3,
                  isPresent: isScanned,
                  index: index,
                );
              },
            ),
          ),

          // ── Contact actions ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Parent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TContactButton(
                        icon: Icons.sms_rounded,
                        label: 'SMS',
                        color: _smsBlue,
                        onTap: phone.isEmpty
                            ? null
                            : () => _launch('sms:+91$phone', context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TContactButton(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp',
                        color: _whatsappGreen,
                        onTap: phone.isEmpty
                            ? null
                            : () => _launch('https://wa.me/91$phone', context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TContactButton(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        color: _callPurple,
                        onTap: phone.isEmpty
                            ? null
                            : () => _launch('tel:+91$phone', context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TQRStudentTile extends StatelessWidget {
  final String name;
  final String roll;
  final String phone;
  final bool isPresent;
  final int index;

  const _TQRStudentTile({
    required this.name,
    required this.roll,
    required this.phone,
    required this.isPresent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPresent ? AppColors.success : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? AppColors.success.withOpacity(0.3)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Text(
              name[0],
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                Text(roll,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPresent ? 'Present' : 'Absent',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 250.ms);
  }
}

class _TContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _TContactButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TScanCorner extends StatelessWidget {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _TScanCorner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(26, 26),
        painter: _TCornerPainter(
          AppColors.success,
          3.0,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      );
}

class _TCornerPainter extends CustomPainter {
  final Color color;
  final double sw;
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _TCornerPainter(this.color, this.sw,
      {this.topLeft = false,
      this.topRight = false,
      this.bottomLeft = false,
      this.bottomRight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final s = size.width;
    if (topLeft) {
      canvas.drawLine(Offset(0, s), const Offset(0, 0), p);
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), p);
    }
    if (topRight) {
      canvas.drawLine(Offset(s, s), Offset(s, 0), p);
      canvas.drawLine(Offset(s, 0), const Offset(0, 0), p);
    }
    if (bottomLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(0, s), p);
      canvas.drawLine(Offset(0, s), Offset(s, s), p);
    }
    if (bottomRight) {
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), p);
      canvas.drawLine(Offset(s, 0), Offset(s, s), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ── Manual Attendance ─────────────────────────────────────────────

class _TManualAttendanceScreen extends StatefulWidget {
  final String className;
  final int total;
  const _TManualAttendanceScreen(
      {required this.className, required this.total});
  @override
  State<_TManualAttendanceScreen> createState() =>
      _TManualAttendanceScreenState();
}

class _TManualAttendanceScreenState extends State<_TManualAttendanceScreen> {
  static const _green = AppColors.success;
  static const _allPhones = [
    '9876543210',
    '9123456780',
    '9988776655',
    '9871234560',
    '9765432100',
    '9654321098',
    '9543210987',
    '9432109876',
    '9321098765',
    '9210987654',
    '9109876543',
    '9098765432',
    '8987654321',
    '8876543210',
    '8765432109',
    '8654321098',
    '8543210987',
    '8432109876',
    '8321098765',
    '8210987654',
    '8109876543',
    '8098765432',
    '7987654321',
    '7876543210',
    '7765432109',
    '7654321098',
    '7543210987',
    '7432109876',
    '7321098765',
    '7210987654',
  ];

  static const _allNames = [
    'Aarav Sharma',
    'Priya Verma',
    'Rohan Singh',
    'Sneha Gupta',
    'Karan Mehta',
    'Ananya Joshi',
    'Dev Patel',
    'Riya Kapoor',
    'Arjun Yadav',
    'Ishaan Kumar',
    'Nisha Tiwari',
    'Raj Malhotra',
    'Simran Kaur',
    'Vivek Mishra',
    'Pooja Nair',
    'Amit Bose',
    'Neha Singh',
    'Rahul Verma',
    'Kavya Iyer',
    'Mohit Saxena',
    'Tanvi Shah',
    'Akash Pandey',
    'Ritu Gupta',
    'Saksham Arora',
    'Divya Choudhary',
    'Harsh Jain',
    'Megha Rathore',
    'Kunal Dubey',
    'Anjali Srivastava',
    'Nikhil Aggarwal',
  ];

  late final List<_TStuEntry> _students;

  @override
  void initState() {
    super.initState();
    final count = widget.total > 30 ? 30 : widget.total;
    _students = List.generate(
      count,
      (i) => _TStuEntry(
        roll: 'R${(i + 1).toString().padLeft(2, '0')}',
        name: _allNames[i % _allNames.length],
        phone: _allPhones[i % _allPhones.length],
        present: true,
      ),
    );
  }

  int get _presentCount => _students.where((s) => s.present).length;

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved — $_presentCount / ${_students.length} present'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
      ),
    );
    Navigator.of(context).pop();
  }

  List<_TStuEntry> get _absentStudents =>
      _students.where((s) => !s.present).toList();

  void _smsAbsent() {
    final absent = _absentStudents;
    if (absent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No absent students today'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // SMS the first absent student as a demo; in production loop or use a bulk SMS API.
    final s = absent.first;
    final now = DateTime.now();
    final months = [
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
      'December',
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';
    final body = Uri.encodeComponent(
      'Your child was marked absent today.\n\n'
      'Student: ${s.name}\nClass: ${widget.className}\nDate: $dateStr',
    );
    launchUrl(Uri.parse('sms:${s.phone}?body=$body'));
  }

  void _callAbsent() {
    final absent = _absentStudents;
    if (absent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No absent students today'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AbsentCallSheet(
        absentStudents: absent,
        className: widget.className,
        accentColor: _green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final absent = _students.length - _presentCount;
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual — ${widget.className}'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: _green.withOpacity(0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TManStat('${_students.length}', 'Total', Colors.black87),
              _TManStat('$_presentCount', 'Present', _green),
              _TManStat('$absent', 'Absent', Colors.redAccent),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _students.forEach((s) => s.present = true)),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark All Present'),
                style: OutlinedButton.styleFrom(foregroundColor: _green),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _students.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final s = _students[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: s.present
                      ? _green.withOpacity(0.12)
                      : Colors.redAccent.withOpacity(0.1),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0] : '?',
                    style: AppTypography.labelLarge.copyWith(
                      color: s.present ? _green : Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(s.name, style: AppTypography.labelMedium),
                subtitle: Text(s.roll,
                    style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5))),
                trailing: Transform.scale(
                  scale: 0.9,
                  child: Switch.adaptive(
                    value: s.present,
                    onChanged: (v) => setState(() => s.present = v),
                    activeColor: _green,
                  ),
                ),
              );
            },
          ),
        ),
        // ── Parent Communication Section ──────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_rounded, size: 16, color: _green),
                  const SizedBox(width: 6),
                  Text(
                    'Parent Communication',
                    style: AppTypography.labelMedium.copyWith(
                      color: _green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_absentStudents.length} absent',
                    style: AppTypography.caption.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _smsAbsent,
                      icon: const Icon(Icons.sms_rounded, size: 18),
                      label: const Text('SMS Parents'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: BorderSide(color: _green.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callAbsent,
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call Parents'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TStuEntry {
  final String roll, name, phone;
  bool present;
  _TStuEntry({
    required this.roll,
    required this.name,
    required this.present,
    this.phone = '',
  });
}

class _TManStat extends StatelessWidget {
  final String val, lbl;
  final Color col;
  const _TManStat(this.val, this.lbl, this.col);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: AppTypography.titleSmall
                .copyWith(color: col, fontWeight: FontWeight.w700)),
        Text(lbl, style: AppTypography.caption),
      ]);
}

// ── Absent students call sheet ────────────────────────────────────

class _AbsentCallSheet extends StatelessWidget {
  final List<_TStuEntry> absentStudents;
  final String className;
  final Color accentColor;
  const _AbsentCallSheet({
    required this.absentStudents,
    required this.className,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.call_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Call Absent Parents',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              Text(
                '${absentStudents.length} absent',
                style: AppTypography.caption.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: absentStudents.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (ctx, i) {
              final s = absentStudents[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0] : '?',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(s.name, style: AppTypography.labelMedium),
                subtitle: Text(
                  '${s.roll}  ·  $className  ·  ${s.phone}',
                  style: AppTypography.caption.copyWith(color: Colors.black54),
                ),
                trailing: IconButton(
                  tooltip: 'Call parent',
                  icon: Icon(Icons.call_rounded, color: accentColor, size: 22),
                  onPressed: () => launchUrl(Uri.parse('tel:${s.phone}')),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── View Attendance ───────────────────────────────────────────────

class _TViewAttendanceScreen extends StatefulWidget {
  final String className;
  const _TViewAttendanceScreen({required this.className});
  @override
  State<_TViewAttendanceScreen> createState() => _TViewAttendanceScreenState();
}

class _TViewAttendanceScreenState extends State<_TViewAttendanceScreen> {
  static const _green = AppColors.success;
  DateTime _selected = DateTime.now();

  static final List<_TAttRecord> _records = List.generate(14, (i) {
    final dt = DateTime.now().subtract(Duration(days: i));
    const total = 42;
    final present = 40 - (i % 4);
    return _TAttRecord(date: dt, total: total, present: present);
  });

  static String _wd(int d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  static String _mn(int m) => const [
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
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    final sel = _records.firstWhere(
      (r) =>
          r.date.day == _selected.day &&
          r.date.month == _selected.month &&
          r.date.year == _selected.year,
      orElse: () => _records.first,
    );
    final absent = sel.total - sel.present;
    final pct = (sel.present / sel.total * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('View — ${widget.className}'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _green.withOpacity(0.06),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_wd(_selected.weekday)}, ${_selected.day} ${_mn(_selected.month)} ${_selected.year}',
                style: AppTypography.labelMedium
                    .copyWith(color: _green, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _selected,
                  firstDate: DateTime.now().subtract(const Duration(days: 180)),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: Theme.of(ctx)
                            .colorScheme
                            .copyWith(primary: _green)),
                    child: child!,
                  ),
                );
                if (p != null) setState(() => _selected = p);
              },
              child: const Text('Change'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _green.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TAStat('${sel.total}', 'Total', Colors.white),
                _TAStat('${sel.present}', 'Present', Colors.white),
                _TAStat('$absent', 'Absent', Colors.white.withOpacity(0.8)),
                _TAStat('$pct%', 'Rate', Colors.white),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Last 14 Days',
                style: AppTypography.labelLarge
                    .copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = _records[i];
              final ab = r.total - r.present;
              final pc = (r.present / r.total * 100).round();
              final isSel = r.date.day == _selected.day &&
                  r.date.month == _selected.month &&
                  r.date.year == _selected.year;
              return InkWell(
                onTap: () => setState(() => _selected = r.date),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _green.withOpacity(0.08)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel
                          ? _green.withOpacity(0.3)
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.15),
                    ),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${_wd(r.date.weekday)}, ${r.date.day} ${_mn(r.date.month)}',
                            style: AppTypography.labelMedium)),
                    _TSBadge('${r.present}P', _green),
                    const SizedBox(width: 6),
                    _TSBadge('${ab}A', Colors.redAccent),
                    const SizedBox(width: 8),
                    Text('$pc%',
                        style: AppTypography.labelSmall.copyWith(
                            color: _green, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn();
            },
          ),
        ),
      ]),
    );
  }
}

class _TAttRecord {
  final DateTime date;
  final int total, present;
  const _TAttRecord(
      {required this.date, required this.total, required this.present});
}

class _TSBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _TSBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: AppTypography.caption
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

// ═══════════════════════════════════════════════════════════════════
// TEACHER PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════

class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const SharedUserProfileScreen();
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCT CATALOGUE — DASHBOARD CARD
// ═══════════════════════════════════════════════════════════════════

class _CatalogueCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CatalogueCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFB45309)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Catalogue',
                    style: AppTypography.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Order ID cards, uniforms, stationery & more',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Browse',
                style: AppTypography.labelSmall
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCT CATALOGUE SCREEN
// ═══════════════════════════════════════════════════════════════════

@immutable
class _TCatalogueProduct {
  final String id;
  final String name;
  final String description;
  final double price;
  final IconData icon;
  final Color color;
  final List<String> templates;

  const _TCatalogueProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    required this.color,
    required this.templates,
  });
}

class _TOrderItem {
  final _TCatalogueProduct product;
  int quantity;
  String selectedTemplate;

  _TOrderItem({
    required this.product,
    this.quantity = 1,
    required this.selectedTemplate,
  });
}

class _TProductCatalogueScreen extends StatefulWidget {
  const _TProductCatalogueScreen();

  @override
  State<_TProductCatalogueScreen> createState() =>
      _TProductCatalogueScreenState();
}

class _TProductCatalogueScreenState extends State<_TProductCatalogueScreen>
    with SingleTickerProviderStateMixin {
  static const _catalogue = [
    _TCatalogueProduct(
      id: 'p1',
      name: 'Student ID Card',
      description: 'Laminated photo ID for students',
      price: 25,
      icon: Icons.badge_outlined,
      color: AppColors.primary,
      templates: ['Classic Blue', 'Modern White', 'School Crest'],
    ),
    _TCatalogueProduct(
      id: 'p2',
      name: 'Staff ID Card',
      description: 'Professional ID for teaching & support staff',
      price: 30,
      icon: Icons.work_outline_rounded,
      color: AppColors.primary,
      templates: ['Professional', 'Compact', 'Full Details'],
    ),
    _TCatalogueProduct(
      id: 'p3',
      name: 'School Uniform Set',
      description: 'Complete uniform set per student',
      price: 850,
      icon: Icons.checkroom_rounded,
      color: AppColors.accent,
      templates: ['Standard Cut', 'Slim Fit'],
    ),
    _TCatalogueProduct(
      id: 'p4',
      name: 'Stationery Pack',
      description: 'Notebooks, pens & geometry box',
      price: 120,
      icon: Icons.edit_outlined,
      color: AppColors.success,
      templates: ['Basic', 'Premium'],
    ),
    _TCatalogueProduct(
      id: 'p5',
      name: 'Report Card Set',
      description: 'Printed report cards per class',
      price: 15,
      icon: Icons.description_outlined,
      color: AppColors.primary,
      templates: ['Default Layout', 'Detailed', 'Compact'],
    ),
  ];

  late final TabController _tabCtrl;
  final Map<String, _TOrderItem> _cart = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _hasItems => _cart.values.any((i) => i.quantity > 0);
  int get _totalItems => _cart.values.fold(0, (s, i) => s + i.quantity);
  double get _totalPrice =>
      _cart.values.fold(0.0, (s, i) => s + i.product.price * i.quantity);

  Future<void> _openProductDetail(_TCatalogueProduct product) async {
    final item = _cart[product.id];
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _TProductDetailScreen(
          product: product,
          initialQty: item?.quantity ?? 0,
          initialTemplate: item?.selectedTemplate,
        ),
      ),
    );
    if (result != null && mounted) {
      final qty = result['qty'] as int;
      setState(() {
        if (qty <= 0) {
          _cart.remove(product.id);
        } else {
          _cart[product.id] = _TOrderItem(
            product: product,
            quantity: qty,
            selectedTemplate: result['template'] as String,
          );
        }
      });
    }
  }

  void _openSendRequest() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TSendRequestSheet(
        items: _cart.values.toList(),
        totalPrice: _totalPrice,
      ),
    ).then((sent) {
      if (sent == true && mounted) setState(() => _cart.clear());
    });
  }

  @override
  Widget build(BuildContext context) {
    final onCatalogueTab = !_tabCtrl.indexIsChanging && _tabCtrl.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalogue'),
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Catalogue'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Catalogue Tab ─────────────────────────────────────────
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _catalogue.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final product = _catalogue[i];
              final item = _cart[product.id];
              final qty = item?.quantity ?? 0;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openProductDetail(product),
                child: PremiumCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: product.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(product.icon, color: product.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: AppTypography.labelLarge
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.description,
                              style: AppTypography.caption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(0)}',
                            style: AppTypography.labelLarge.copyWith(
                              color: product.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (qty > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: product.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '× $qty in cart',
                                style: AppTypography.caption.copyWith(
                                  color: product.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                          size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
          // ── My Requests Tab ───────────────────────────────────────
          Builder(builder: (context) {
            final myRequests = OrderRequestStore.all
                .where((r) => r.teacherName == 'Mr. S. Sharma')
                .toList();
            if (myRequests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 56,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.35)),
                    const SizedBox(height: 12),
                    Text(
                      'No requests sent yet',
                      style: AppTypography.labelLarge.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add items from the Catalogue tab\nand send a request to the principal.',
                      style: AppTypography.caption.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: myRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final req = myRequests[i];
                return _OrderRequestTile(
                  request: req,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _TOrderRequestDetailScreen(request: req),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
      bottomNavigationBar: onCatalogueTab
          ? AnimatedSlide(
              offset: _hasItems ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _hasItems ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: ElevatedButton(
                      onPressed: _hasItems ? _openSendRequest : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Request Items  •  $_totalItems item${_totalItems == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            '₹${_totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CATALOGUE HELPERS
// ═══════════════════════════════════════════════════════════════════

class _TQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  const _TQtyButton({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null
              ? c.withOpacity(0.12)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null
                ? c
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEND REQUEST SHEET
// ═══════════════════════════════════════════════════════════════════

class _TSendRequestSheet extends StatefulWidget {
  final List<_TOrderItem> items;
  final double totalPrice;
  const _TSendRequestSheet({required this.items, required this.totalPrice});

  @override
  State<_TSendRequestSheet> createState() => _TSendRequestSheetState();
}

class _TSendRequestSheetState extends State<_TSendRequestSheet> {
  bool _sending = false;
  bool _sent = false;
  OrderRequest? _req;

  Future<void> _send() async {
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 800));
    final req = OrderRequestStore.submit(
      teacherName: 'Mr. S. Sharma',
      items: widget.items
          .map((i) => OrderItem(
                productId: i.product.id,
                productName: i.product.name,
                unitPrice: i.product.price,
                quantity: i.quantity,
                selectedTemplate: i.selectedTemplate,
              ))
          .toList(),
      totalPrice: widget.totalPrice,
    );
    if (mounted) {
      setState(() {
        _sending = false;
        _sent = true;
        _req = req;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 72),
            const SizedBox(height: 16),
            Text('Request Sent!',
                style: AppTypography.titleLarge
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your request (${_req!.id}) has been sent to the principal for approval.',
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text('Order Summary',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '₹${widget.totalPrice.toStringAsFixed(0)}',
                  style: AppTypography.titleMedium.copyWith(
                    color: const Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = widget.items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(item.product.icon,
                          color: item.product.color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: AppTypography.labelMedium
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Template: ${item.selectedTemplate}',
                              style: AppTypography.caption
                                  .copyWith(color: item.product.color),
                            ),
                          ],
                        ),
                      ),
                      Text('× ${item.quantity}', style: AppTypography.caption),
                      const SizedBox(width: 12),
                      Text(
                        '₹${(item.product.price * item.quantity).toStringAsFixed(0)}',
                        style: AppTypography.labelMedium.copyWith(
                          color: item.product.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '₹${widget.totalPrice.toStringAsFixed(0)}',
                      style: AppTypography.titleSmall.copyWith(
                        color: const Color(0xFFD97706),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label:
                      Text(_sending ? 'Sending…' : 'Send Request to Principal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRODUCT DETAIL SCREEN (TEACHER)
// ═══════════════════════════════════════════════════════════════════

class _TProductDetailScreen extends StatefulWidget {
  final _TCatalogueProduct product;
  final int initialQty;
  final String? initialTemplate;

  const _TProductDetailScreen({
    required this.product,
    this.initialQty = 0,
    this.initialTemplate,
  });

  @override
  State<_TProductDetailScreen> createState() => _TProductDetailScreenState();
}

class _TProductDetailScreenState extends State<_TProductDetailScreen> {
  late int _qty;
  late String _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    _selectedTemplate =
        widget.initialTemplate ?? widget.product.templates.first;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: product.color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    product.color.withOpacity(0.12),
                    product.color.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: product.color.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Icon(product.icon, color: product.color, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    product.name,
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹${product.price.toStringAsFixed(0)} per unit',
                    style: AppTypography.titleMedium.copyWith(
                      color: product.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Quantity
            Row(
              children: [
                Text('Quantity',
                    style: AppTypography.titleSmall
                        .copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Row(
                  children: [
                    _TQtyButton(
                      icon: Icons.remove,
                      onTap: _qty > 0 ? () => setState(() => _qty--) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_qty',
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _TQtyButton(
                      icon: Icons.add,
                      onTap: () => setState(() => _qty++),
                      color: product.color,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            // Templates
            Text('Design Template',
                style: AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...product.templates.map((t) {
              final isSelected = t == _selectedTemplate;
              return GestureDetector(
                onTap: () => setState(() => _selectedTemplate = t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? product.color.withOpacity(0.1)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? product.color
                          : Colors.grey.withOpacity(0.2),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? product.color : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t,
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? product.color : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: product.color, size: 18),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop({
              'qty': _qty,
              'template': _selectedTemplate,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: product.color,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              _qty == 0
                  ? 'Remove from Cart'
                  : 'Add $_qty to Cart  •  ₹${(product.price * _qty).toStringAsFixed(0)}',
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ORDER REQUEST DETAIL (TEACHER VIEW)
// ═══════════════════════════════════════════════════════════════════

class _TOrderRequestDetailScreen extends StatelessWidget {
  final OrderRequest request;
  const _TOrderRequestDetailScreen({required this.request});

  Color _statusColor(OrderRequest r) {
    switch (r.status) {
      case OrderStatus.pending:
        return const Color(0xFFD97706);
      case OrderStatus.approved:
        return AppColors.success;
      case OrderStatus.rejected:
        return AppColors.error;
    }
  }

  String _statusLabel(OrderRequest r) {
    switch (r.status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.approved:
        return 'Approved';
      case OrderStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(request);
    final sl = _statusLabel(request);
    return Scaffold(
      appBar: AppBar(
        title: Text(request.id),
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sc.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    request.status == OrderStatus.approved
                        ? Icons.check_circle_rounded
                        : request.status == OrderStatus.rejected
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded,
                    color: sc,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sl,
                            style: AppTypography.titleSmall.copyWith(
                              color: sc,
                              fontWeight: FontWeight.w700,
                            )),
                        Text(
                          'Submitted on ${_fmtDate(request.requestedAt)}',
                          style: AppTypography.caption.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                        ),
                        if (request.note != null && request.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Note: ${request.note}',
                                style:
                                    AppTypography.caption.copyWith(color: sc)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Ordered Items',
                style: AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...request.items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                style: AppTypography.labelMedium
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              'Template: ${item.selectedTemplate}',
                              style: AppTypography.caption.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                      Text('× ${item.quantity}', style: AppTypography.caption),
                      const SizedBox(width: 12),
                      Text(
                        '₹${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                        style: AppTypography.labelMedium.copyWith(
                          color: const Color(0xFFD97706),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: AppTypography.titleSmall
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '₹${request.totalPrice.toStringAsFixed(0)}',
                  style: AppTypography.titleSmall.copyWith(
                    color: const Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════
// ORDER REQUEST TILE (shared helper)
// ═══════════════════════════════════════════════════════════════════

class _OrderRequestTile extends StatelessWidget {
  final OrderRequest request;
  final VoidCallback onTap;
  const _OrderRequestTile({required this.request, required this.onTap});

  Color get _sc {
    switch (request.status) {
      case OrderStatus.pending:
        return const Color(0xFFD97706);
      case OrderStatus.approved:
        return AppColors.success;
      case OrderStatus.rejected:
        return AppColors.error;
    }
  }

  String get _sl {
    switch (request.status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.approved:
        return 'Approved';
      case OrderStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: PremiumCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _sc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long_rounded, color: _sc, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.id,
                      style: AppTypography.labelLarge
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${request.items.length} item${request.items.length == 1 ? '' : 's'}  •  ₹${request.totalPrice.toStringAsFixed(0)}',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _sc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_sl,
                  style: AppTypography.caption.copyWith(
                    color: _sc,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}
