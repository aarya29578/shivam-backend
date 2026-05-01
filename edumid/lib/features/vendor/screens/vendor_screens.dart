import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as xl;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/class_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../core/api/api_config.dart';
import '../models/client.dart';
import '../models/product.dart';
import 'product_selection_screen.dart';
import 'product_detail_screen.dart';
import 'quick_capture_screen.dart';

/// Shared Dio instance with sensible timeouts for all vendor API calls.
Dio _dio() => Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

/// Auth-aware Dio instance for endpoints that require a Bearer token.
Dio _dioWithAuth(String? token) => Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: (token != null && token.isNotEmpty)
          ? {'Authorization': 'Bearer $token'}
          : null,
    ));

/// Base URL for the Node.js backend (configured globally)
/// See: lib/core/api/api_config.dart
const String _kServerBase = ApiConfig.baseUrl;

Future<String> _currentVendorId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyUserData);
    if (raw == null || raw.isEmpty) return 'vendor_001';

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final id = (map['id'] ?? '').toString().trim();
    return id.isEmpty ? 'vendor_001' : id;
  } catch (_) {
    return 'vendor_001';
  }
}

/// Increment this from VendorShell when the Home tab is tapped
/// to force VendorDashboardScreen to reload from the server.
final ValueNotifier<int> vendorDashboardRefreshTrigger = ValueNotifier<int>(0);

// -------------------------------------------------------------------
// VENDOR DASHBOARD
// -------------------------------------------------------------------
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  // -- API config ------------------------------------------------
  // localhost only works on an Android emulator (use 10.0.2.2 there).
  // For a real physical device use your machine's Wi-Fi LAN IP instead.
  static const _kBaseUrl = _kServerBase;

  // -- State -----------------------------------------------------
  bool _loading = true;
  String? _error;
  // runtime-selected base URL (falls back to ApiConfig.baseUrl)
  String _activeBase = _kBaseUrl;
  String _vendorId = '';
  int _totalClients = 0;
  int _activeOrders = 0;
  String _cardsToday = '0';
  List<Map<String, dynamic>> _activeProjects = [];
  List<_VendorSchoolEntry> _schools = [];
  List<Map<String, dynamic>> _dashboardClients = [];

  static const _kColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.roleTeacher,
    AppColors.accent,
    AppColors.success,
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    vendorDashboardRefreshTrigger.addListener(_loadDashboard);
  }

  @override
  void dispose() {
    vendorDashboardRefreshTrigger.removeListener(_loadDashboard);
    super.dispose();
  }

  Future<void> _loadDashboard({int attempt = 0}) async {
    try {
      final vendorId = await _currentVendorId();

      // Try current active base first, then fallbacks (LAN, localhost, emulator)
      final candidates = [
        _activeBase,
        ApiConfig.baseUrl,
        'http://192.168.1.61:5001',
        'http://127.0.0.1:5001',
        'http://10.0.2.2:5001',
      ];

      Object? lastError;
      for (final base in candidates) {
        try {
          final dio = Dio(BaseOptions(
            baseUrl: base,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ));

          final results = await Future.wait([
            dio.get('/api/vendor/dashboard',
                queryParameters: {'vendorId': vendorId}),
            dio.get('/api/vendor/clients',
                queryParameters: {'vendorId': vendorId}),
          ]);

          final data = results[0].data as Map<String, dynamic>;
          final clientsData =
              (results[1].data as List).cast<Map<String, dynamic>>();

          final rawProjects = (data['activeProjects'] as List? ?? []);
          final projects = rawProjects
              .map<Map<String, dynamic>>((p) => {
                    'school': (p['schoolName'] ?? '') as String,
                    'stage': (p['stage'] ?? '') as String,
                    'progress': ((p['progress'] as num? ?? 0) / 100.0),
                    'count': '',
                  })
              .toList();

          final rawSchools = (data['schools'] as List? ?? []);
          final schools =
              rawSchools.asMap().entries.map<_VendorSchoolEntry>((e) {
            final s = e.value as Map<String, dynamic>;
            return _VendorSchoolEntry(
              name: (s['schoolName'] ?? '') as String,
              city: (s['city'] ?? '') as String,
              board: 'CBSE',
              totalStudents: 0,
              color: _kColors[e.key % _kColors.length],
              clientId: (s['clientId'] ?? '') as String,
              principalId: (s['principalId'] ?? '') as String,
            );
          }).toList();

          final cards = (data['cardsToday'] as num? ?? 0).toInt();
          final cardsStr = cards >= 1000
              ? '${(cards / 1000).toStringAsFixed(1)}K'
              : '$cards';

          if (!mounted) return;
          setState(() {
            _activeBase = base;
            _totalClients = (data['totalClients'] as num? ?? 0).toInt();
            _activeOrders = (data['activeOrders'] as num? ?? 0).toInt();
            _cardsToday = cardsStr;
            _activeProjects = projects;
            _schools = schools;
            _dashboardClients = clientsData;
            _vendorId = vendorId;
            _loading = false;
            _error = null;
          });
          return;
        } catch (e) {
          lastError = e;
          // try next candidate
        }
      }

      // if we reach here, all candidates failed
      if (lastError != null) throw lastError;
    } catch (e, st) {
      debugPrint('[VendorDashboard] load error: $e\n$st');
      // Auto-retry once on connection errors before showing the error UI
      if (attempt == 0 &&
          e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) return _loadDashboard(attempt: 1);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _showClientOptions(BuildContext context, Map<String, dynamic> client) {
    final id = client['id'].toString();
    final name = client['schoolName'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    AppAvatar(name: name, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.labelLarge),
                          if ((client['city'] as String? ?? '').isNotEmpty)
                            Text(client['city'] as String,
                                style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_box_rounded,
                      color: AppColors.primary),
                ),
                title: const Text('Add Order'),
                subtitle: const Text('Create a new order for this client'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/vendor/clients/$id');
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_open_rounded,
                      color: AppColors.secondary),
                ),
                title: const Text('View Orders'),
                subtitle: const Text('See all orders for this client'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/vendor/clients/$id');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 162,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  tooltip: 'Share App',
                  onPressed: () => Share.share(
                    'EduMid � India\'s #1 School ID Card App ??\nInstall now: https://edumid.app',
                    subject: 'Check out EduMid App!',
                  ),
                ),
                NotificationBadge(
                  count: 2,
                  child: IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
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
                          Text('Good Morning ??',
                              style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.8))),
                          Text('Print Solutions Ltd.',
                              style: AppTypography.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          Text('Vendor',
                              style: AppTypography.caption.copyWith(
                                  color: Colors.white.withOpacity(0.65))),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _VendorStat('Active Orders',
                                  _loading ? '�' : '$_activeOrders'),
                              _VendorStat(
                                  'Clients', _loading ? '�' : '$_totalClients'),
                              _VendorStat(
                                  'Cards Today', _loading ? '�' : _cardsToday),
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
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                          child: _VendorActionCard(
                        icon: Icons.people_rounded,
                        label: 'Clients',
                        color: AppColors.primary,
                        onTap: () => context.go('/vendor/clients'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _VendorActionCard(
                        icon: Icons.upload_rounded,
                        label: 'Upload',
                        color: AppColors.secondary,
                        onTap: () => context.go('/vendor/upload-excel'),
                      )),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),
                  // Add Client button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/vendor/clients/add'),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Client'),
                    ),
                  ).animate().fadeIn(delay: 220.ms),
                  const SizedBox(height: 12),
                  // Add Order button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/vendor/orders/create'),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('Add Order'),
                    ),
                  ).animate().fadeIn(delay: 230.ms),
                  const SizedBox(height: 24),
                  // My Clients section
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Could not load data',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _error!,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.red),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _loadDashboard();
                                },
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Retry'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_dashboardClients.isNotEmpty)
                    ...([
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'My Clients',
                            style: AppTypography.titleSmall
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/vendor/clients'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._dashboardClients.map((c) {
                        final name = c['schoolName'] as String? ?? '';
                        final id = c['id'].toString();
                        return PremiumCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: () => context.push('/vendor/clients/$id'),
                          child: Row(
                            children: [
                              AppAvatar(name: name, radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: AppTypography.labelMedium),
                                    if ((c['city'] as String? ?? '').isNotEmpty)
                                      Text(c['city'] as String,
                                          style: AppTypography.bodySmall),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showClientOptions(context, c),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    color: AppColors.primary.withOpacity(0.6),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ]),
                  SectionHeader(
                    title: 'Active Projects',
                    action: 'View All',
                    onAction: () => context.go('/vendor/project-board'),
                  ),
                  const SizedBox(height: 12),
                  ...(_loading
                      ? [
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator()))
                        ]
                      : _activeProjects.isEmpty
                          ? const [SizedBox.shrink()]
                          : _activeProjects
                              .map((p) => _ActiveProjectCard(project: p))
                              .toList()),
                  const SizedBox(height: 24),
                  // -- School Data --------------------------------
                  Row(children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('School Data',
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _VendorSchoolListScreen(
                          schools: _schools, vendorId: _vendorId),
                    )),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Schools',
                                  style: AppTypography.labelLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                              const SizedBox(height: 3),
                              Text('Tap to browse all schools',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_schools.length}',
                            style: AppTypography.titleSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.primary.withOpacity(0.6)),
                      ]),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 250.ms)
                      .slideX(begin: 0.04, end: 0),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorStat extends StatelessWidget {
  final String label;
  final String value;
  const _VendorStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTypography.titleMedium.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _VendorActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _VendorActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  const _ActiveProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child:
                      Text(project['school'], style: AppTypography.labelLarge)),
              RoleBadge(label: project['stage'], color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project['progress'],
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(project['count'], style: AppTypography.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// CLIENT LIST
// -------------------------------------------------------------------
class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  static const _kBaseUrl = _kServerBase;

  String _q = '';
  bool _loading = true;
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final vendorId = await _currentVendorId();
      final response = await _dio().get(
        '$_kBaseUrl/api/vendor/clients',
        queryParameters: {'vendorId': vendorId},
      );
      final data = (response.data as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _clients = data;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[ClientList] load error: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load clients: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteClient(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _dio().delete('$_kBaseUrl/api/vendor/clients/$id');
      if (!mounted) return;
      setState(() => _clients.removeWhere((c) => c['id'].toString() == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to delete client.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _clients
        .where((c) => (c['schoolName'] as String? ?? '')
            .toLowerCase()
            .contains(_q.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add_rounded),
              onPressed: () async {
                final added = await context.push<bool>('/vendor/clients/add');
                if (added == true && mounted) _loadClients();
              }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: AppTextField(
              label: '',
              hint: 'Search clients...',
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _clients.isEmpty ? 'No clients yet' : 'No results',
                          style: AppTypography.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          final name = c['schoolName'] as String? ?? '';
                          final id = c['id'].toString();
                          return PremiumCard(
                            onTap: () async {
                              final deleted = await context
                                  .push<bool>('/vendor/clients/$id');
                              if (deleted == true && mounted) _loadClients();
                            },
                            child: Row(
                              children: [
                                AppAvatar(name: name, radius: 22),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: AppTypography.labelLarge),
                                      Text(c['city'] as String? ?? '',
                                          style: AppTypography.bodySmall),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onSelected: (v) {
                                    if (v == 'delete') _deleteClient(id, name);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded,
                                              color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
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

// -------------------------------------------------------------------
// ADD CLIENT - UPGRADED WITH FULL PRODUCTION FIELDS
// -------------------------------------------------------------------
class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  static const _kBaseUrl = _kServerBase;

  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  // Basic Info Controllers
  final _schoolNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // GST Details Controllers
  final _gstNumberCtrl = TextEditingController();
  final _gstNameCtrl = TextEditingController();
  final _gstStateCodeCtrl = TextEditingController();
  final _gstAddressCtrl = TextEditingController();

  // Transport Details Controllers
  final _busStopCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();

  // Location Details Controllers
  final _pincodeCtrl = TextEditingController();

  // Extra Controllers
  final _schoolUniqueIdCtrl = TextEditingController();

  // Radio/Dropdown State
  String? _deliveryMode; // 'Bus' or 'Courier'
  String? _clientType; // 'School', 'Coaching', 'Other'
  String? _state;
  String? _district;

  // Lists for dropdowns
  static const List<String> _states = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Puducherry',
    'Ladakh',
    'Jammu and Kashmir',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Lakshadweep',
    'Andaman and Nicobar Islands',
  ];

  static const Map<String, List<String>> _districtsByState = {
    'Delhi': [
      'Central Delhi',
      'East Delhi',
      'New Delhi',
      'North Delhi',
      'North East Delhi',
      'North West Delhi',
      'Shahdara',
      'South Delhi',
      'South East Delhi',
      'South West Delhi',
      'West Delhi',
    ],
    'Maharashtra': [
      'Ahmednagar',
      'Akola',
      'Amravati',
      'Aurangabad',
      'Beed',
      'Bhandara',
      'Buldhana',
      'Chandrapur',
      'Dhule',
      'Gadchiroli',
      'Gondia',
      'Hingoli',
      'Jalgaon',
      'Jalna',
      'Kolhapur',
      'Latur',
      'Mumbai City',
      'Mumbai Suburban',
      'Nagpur',
      'Nanded',
      'Nandurbar',
      'Nashik',
      'Osmanabad',
      'Palghar',
      'Parbhani',
      'Pune',
      'Raigad',
      'Ratnagiri',
      'Sangli',
      'Satara',
      'Sindhudurg',
      'Solapur',
      'Thane',
      'Wardha',
      'Washim',
      'Yavatmal',
    ],
    'Karnataka': [
      'Bagalkot',
      'Ballari',
      'Belagavi',
      'Bengaluru Rural',
      'Bengaluru Urban',
      'Bidar',
      'Chamarajanagar',
      'Chikkaballapur',
      'Chikkamagaluru',
      'Chitradurga',
      'Dakshina Kannada',
      'Davanagere',
      'Dharwad',
      'Gadag',
      'Hassan',
      'Haveri',
      'Kalaburagi',
      'Kodagu',
      'Kolar',
      'Koppal',
      'Mandya',
      'Mysuru',
      'Raichur',
      'Ramanagara',
      'Shivamogga',
      'Tumakuru',
      'Udupi',
      'Uttara Kannada',
      'Vijayapura',
      'Yadgir',
    ],
    'Uttar Pradesh': [
      'Agra',
      'Aligarh',
      'Ambedkar Nagar',
      'Amethi',
      'Amroha',
      'Auraiya',
      'Ayodhya',
      'Azamgarh',
      'Baghpat',
      'Bahraich',
      'Ballia',
      'Balrampur',
      'Banda',
      'Barabanki',
      'Bareilly',
      'Basti',
      'Bhadohi',
      'Bijnor',
      'Budaun',
      'Bulandshahr',
      'Chandauli',
      'Chitrakoot',
      'Deoria',
      'Etah',
      'Etawah',
      'Farrukhabad',
      'Fatehpur',
      'Firozabad',
      'Gautam Buddha Nagar',
      'Ghaziabad',
      'Ghazipur',
      'Gonda',
      'Gorakhpur',
      'Hamirpur',
      'Hapur',
      'Hardoi',
      'Hathras',
      'Jalaun',
      'Jaunpur',
      'Jhansi',
      'Kannauj',
      'Kanpur Dehat',
      'Kanpur Nagar',
      'Kasganj',
      'Kaushambi',
      'Kushinagar',
      'Lakhimpur Kheri',
      'Lalitpur',
      'Lucknow',
      'Maharajganj',
      'Mahoba',
      'Mainpuri',
      'Mathura',
      'Mau',
      'Meerut',
      'Mirzapur',
      'Moradabad',
      'Muzaffarnagar',
      'Pilibhit',
      'Pratapgarh',
      'Prayagraj',
      'Rae Bareli',
      'Rampur',
      'Saharanpur',
      'Sambhal',
      'Sant Kabir Nagar',
      'Shahjahanpur',
      'Shamli',
      'Shravasti',
      'Siddharthnagar',
      'Sitapur',
      'Sonbhadra',
      'Sultanpur',
      'Unnao',
      'Varanasi',
    ],
    'Tamil Nadu': [
      'Ariyalur',
      'Chengalpattu',
      'Chennai',
      'Coimbatore',
      'Cuddalore',
      'Dharmapuri',
      'Dindigul',
      'Erode',
      'Kallakurichi',
      'Kanchipuram',
      'Kanyakumari',
      'Karur',
      'Krishnagiri',
      'Madurai',
      'Mayiladuthurai',
      'Nagapattinam',
      'Namakkal',
      'Nilgiris',
      'Perambalur',
      'Pudukkottai',
      'Ramanathapuram',
      'Ranipet',
      'Salem',
      'Sivaganga',
      'Tenkasi',
      'Thanjavur',
      'Theni',
      'Thoothukudi',
      'Tiruchirappalli',
      'Tirunelveli',
      'Tirupathur',
      'Tiruppur',
      'Tiruvallur',
      'Tiruvannamalai',
      'Tiruvarur',
      'Vellore',
      'Viluppuram',
      'Virudhunagar',
    ],
    'Rajasthan': [
      'Ajmer',
      'Alwar',
      'Banswara',
      'Baran',
      'Barmer',
      'Bharatpur',
      'Bhilwara',
      'Bikaner',
      'Bundi',
      'Chittorgarh',
      'Churu',
      'Dausa',
      'Dholpur',
      'Dungarpur',
      'Hanumangarh',
      'Jaipur',
      'Jaisalmer',
      'Jalore',
      'Jhalawar',
      'Jhunjhunu',
      'Jodhpur',
      'Karauli',
      'Kota',
      'Nagaur',
      'Pali',
      'Pratapgarh',
      'Rajsamand',
      'Sawai Madhopur',
      'Sikar',
      'Sirohi',
      'Sri Ganganagar',
      'Tonk',
      'Udaipur',
    ],
    'Gujarat': [
      'Ahmedabad',
      'Amreli',
      'Anand',
      'Aravalli',
      'Banaskantha',
      'Bharuch',
      'Bhavnagar',
      'Botad',
      'Chhota Udaipur',
      'Dahod',
      'Dang',
      'Devbhoomi Dwarka',
      'Gandhinagar',
      'Gir Somnath',
      'Jamnagar',
      'Junagadh',
      'Kheda',
      'Kutch',
      'Mahisagar',
      'Mehsana',
      'Morbi',
      'Narmada',
      'Navsari',
      'Panchmahal',
      'Patan',
      'Porbandar',
      'Rajkot',
      'Sabarkantha',
      'Surat',
      'Surendranagar',
      'Tapi',
      'Vadodara',
      'Valsad',
    ],
    'West Bengal': [
      'Alipurduar',
      'Bankura',
      'Birbhum',
      'Cooch Behar',
      'Dakshin Dinajpur',
      'Darjeeling',
      'Hooghly',
      'Howrah',
      'Jalpaiguri',
      'Jhargram',
      'Kalimpong',
      'Kolkata',
      'Malda',
      'Murshidabad',
      'Nadia',
      'North 24 Parganas',
      'Paschim Bardhaman',
      'Paschim Medinipur',
      'Purba Bardhaman',
      'Purba Medinipur',
      'Purulia',
      'South 24 Parganas',
      'Uttar Dinajpur',
    ],
    'Madhya Pradesh': [
      'Agar Malwa',
      'Alirajpur',
      'Anuppur',
      'Ashoknagar',
      'Balaghat',
      'Barwani',
      'Betul',
      'Bhind',
      'Bhopal',
      'Burhanpur',
      'Chachaura',
      'Chhatarpur',
      'Chhindwara',
      'Damoh',
      'Datia',
      'Dewas',
      'Dhar',
      'Dindori',
      'Guna',
      'Gwalior',
      'Harda',
      'Hoshangabad',
      'Indore',
      'Jabalpur',
      'Jhabua',
      'Katni',
      'Khandwa',
      'Khargone',
      'Mandla',
      'Mandsaur',
      'Morena',
      'Narsinghpur',
      'Neemuch',
      'Niwari',
      'Panna',
      'Raisen',
      'Rajgarh',
      'Ratlam',
      'Rewa',
      'Sagar',
      'Satna',
      'Sehore',
      'Seoni',
      'Shahdol',
      'Shajapur',
      'Sheopur',
      'Shivpuri',
      'Sidhi',
      'Singrauli',
      'Tikamgarh',
      'Ujjain',
      'Umaria',
      'Vidisha',
    ],
    'Bihar': [
      'Araria',
      'Arwal',
      'Aurangabad',
      'Banka',
      'Begusarai',
      'Bhagalpur',
      'Bhojpur',
      'Buxar',
      'Darbhanga',
      'East Champaran',
      'Gaya',
      'Gopalganj',
      'Jamui',
      'Jehanabad',
      'Kaimur',
      'Katihar',
      'Khagaria',
      'Kishanganj',
      'Lakhisarai',
      'Madhepura',
      'Madhubani',
      'Munger',
      'Muzaffarpur',
      'Nalanda',
      'Nawada',
      'Patna',
      'Purnia',
      'Rohtas',
      'Saharsa',
      'Samastipur',
      'Saran',
      'Sheikhpura',
      'Sheohar',
      'Sitamarhi',
      'Siwan',
      'Supaul',
      'Vaishali',
      'West Champaran',
    ],
    'Haryana': [
      'Ambala',
      'Bhiwani',
      'Charkhi Dadri',
      'Faridabad',
      'Fatehabad',
      'Gurugram',
      'Hisar',
      'Jhajjar',
      'Jind',
      'Kaithal',
      'Karnal',
      'Kurukshetra',
      'Mahendragarh',
      'Nuh',
      'Palwal',
      'Panchkula',
      'Panipat',
      'Rewari',
      'Rohtak',
      'Sirsa',
      'Sonipat',
      'Yamunanagar',
    ],
    'Punjab': [
      'Amritsar',
      'Barnala',
      'Bathinda',
      'Faridkot',
      'Fatehgarh Sahib',
      'Fazilka',
      'Firozpur',
      'Gurdaspur',
      'Hoshiarpur',
      'Jalandhar',
      'Kapurthala',
      'Ludhiana',
      'Mansa',
      'Moga',
      'Mohali',
      'Muktsar',
      'Pathankot',
      'Patiala',
      'Rupnagar',
      'Sangrur',
      'Shaheed Bhagat Singh Nagar',
      'Tarn Taran',
    ],
    'Himachal Pradesh': [
      'Bilaspur',
      'Chamba',
      'Hamirpur',
      'Kangra',
      'Kinnaur',
      'Kullu',
      'Lahaul and Spiti',
      'Mandi',
      'Shimla',
      'Sirmaur',
      'Solan',
      'Una',
    ],
    'Uttarakhand': [
      'Almora',
      'Bageshwar',
      'Chamoli',
      'Champawat',
      'Dehradun',
      'Haridwar',
      'Nainital',
      'Pauri Garhwal',
      'Pithoragarh',
      'Rudraprayag',
      'Tehri Garhwal',
      'Udham Singh Nagar',
      'Uttarkashi',
    ],
    'Jharkhand': [
      'Bokaro',
      'Chatra',
      'Deoghar',
      'Dhanbad',
      'Dumka',
      'East Singhbhum',
      'Garhwa',
      'Giridih',
      'Godda',
      'Gumla',
      'Hazaribagh',
      'Jamtara',
      'Khunti',
      'Koderma',
      'Latehar',
      'Lohardaga',
      'Pakur',
      'Palamu',
      'Ramgarh',
      'Ranchi',
      'Sahebganj',
      'Seraikela Kharsawan',
      'Simdega',
      'West Singhbhum',
    ],
    'Chhattisgarh': [
      'Balod',
      'Baloda Bazar',
      'Balrampur',
      'Bastar',
      'Bemetara',
      'Bijapur',
      'Bilaspur',
      'Dantewada',
      'Dhamtari',
      'Durg',
      'Gariaband',
      'Gaurela Pendra Marwahi',
      'Janjgir Champa',
      'Jashpur',
      'Kabirdham',
      'Kanker',
      'Kondagaon',
      'Korba',
      'Koriya',
      'Mahasamund',
      'Mungeli',
      'Narayanpur',
      'Raigarh',
      'Raipur',
      'Rajnandgaon',
      'Sukma',
      'Surajpur',
      'Surguja',
    ],
    'Andhra Pradesh': [
      'Alluri Sitharama Raju',
      'Anakapalli',
      'Ananthapuramu',
      'Annamayya',
      'Bapatla',
      'Chittoor',
      'East Godavari',
      'Eluru',
      'Guntur',
      'Kakinada',
      'Krishna',
      'Kurnool',
      'Nandyal',
      'NTR',
      'Palnadu',
      'Parvathipuram Manyam',
      'Prakasam',
      'Sri Potti Sriramulu Nellore',
      'Sri Sathya Sai',
      'Srikakulam',
      'Tirupati',
      'Visakhapatnam',
      'Vizianagaram',
      'West Godavari',
      'YSR Kadapa',
    ],
    'Telangana': [
      'Adilabad',
      'Bhadradri Kothagudem',
      'Hanamkonda',
      'Hyderabad',
      'Jagtial',
      'Jangaon',
      'Jayashankar Bhupalpally',
      'Jogulamba Gadwal',
      'Kamareddy',
      'Karimnagar',
      'Khammam',
      'Kumuram Bheem',
      'Mahabubabad',
      'Mahabubnagar',
      'Mancherial',
      'Medak',
      'Medchal Malkajgiri',
      'Mulugu',
      'Nagarkurnool',
      'Nalgonda',
      'Narayanpet',
      'Nirmal',
      'Nizamabad',
      'Peddapalli',
      'Rajanna Sircilla',
      'Rangareddy',
      'Sangareddy',
      'Siddipet',
      'Suryapet',
      'Vikarabad',
      'Wanaparthy',
      'Warangal',
      'Yadadri Bhuvanagiri',
    ],
    'Kerala': [
      'Alappuzha',
      'Ernakulam',
      'Idukki',
      'Kannur',
      'Kasaragod',
      'Kollam',
      'Kottayam',
      'Kozhikode',
      'Malappuram',
      'Palakkad',
      'Pathanamthitta',
      'Thiruvananthapuram',
      'Thrissur',
      'Wayanad',
    ],
    'Odisha': [
      'Angul',
      'Balangir',
      'Balasore',
      'Bargarh',
      'Bhadrak',
      'Boudh',
      'Cuttack',
      'Deogarh',
      'Dhenkanal',
      'Gajapati',
      'Ganjam',
      'Jagatsinghpur',
      'Jajpur',
      'Jharsuguda',
      'Kalahandi',
      'Kandhamal',
      'Kendrapara',
      'Kendujhar',
      'Khordha',
      'Koraput',
      'Malkangiri',
      'Mayurbhanj',
      'Nabarangpur',
      'Nayagarh',
      'Nuapada',
      'Puri',
      'Rayagada',
      'Sambalpur',
      'Subarnapur',
      'Sundargarh',
    ],
    'Assam': [
      'Bajali',
      'Baksa',
      'Barpeta',
      'Biswanath',
      'Bongaigaon',
      'Cachar',
      'Charaideo',
      'Chirang',
      'Darrang',
      'Dhemaji',
      'Dhubri',
      'Dibrugarh',
      'Dima Hasao',
      'Goalpara',
      'Golaghat',
      'Hailakandi',
      'Hojai',
      'Jorhat',
      'Kamrup',
      'Kamrup Metropolitan',
      'Karbi Anglong',
      'Karimganj',
      'Kokrajhar',
      'Lakhimpur',
      'Majuli',
      'Morigaon',
      'Nagaon',
      'Nalbari',
      'Sivasagar',
      'Sonitpur',
      'South Salmara Mankachar',
      'Tinsukia',
      'Udalguri',
      'West Karbi Anglong',
    ],
    'Goa': [
      'North Goa',
      'South Goa',
    ],
    'Jammu and Kashmir': [
      'Anantnag',
      'Bandipora',
      'Baramulla',
      'Budgam',
      'Doda',
      'Ganderbal',
      'Jammu',
      'Kathua',
      'Kishtwar',
      'Kulgam',
      'Kupwara',
      'Poonch',
      'Pulwama',
      'Rajouri',
      'Ramban',
      'Reasi',
      'Samba',
      'Shopian',
      'Srinagar',
      'Udhampur',
    ],
    'Ladakh': [
      'Kargil',
      'Leh',
    ],
    'Puducherry': [
      'Karaikal',
      'Mahe',
      'Puducherry',
      'Yanam',
    ],
    'Chandigarh': [
      'Chandigarh',
    ],
  };

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _contactNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstNumberCtrl.dispose();
    _gstNameCtrl.dispose();
    _gstStateCodeCtrl.dispose();
    _gstAddressCtrl.dispose();
    _busStopCtrl.dispose();
    _routeCtrl.dispose();
    _pincodeCtrl.dispose();
    _schoolUniqueIdCtrl.dispose();
    super.dispose();
  }

  /// Validate required fields
  bool _validateForm() {
    final schoolName = _schoolNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (schoolName.isEmpty) {
      _showError('School name is required.');
      return false;
    }

    if (phone.isEmpty) {
      _showError('Phone number is required.');
      return false;
    }

    if (!RegExp(r'^[0-9\s\-\+]{10,}$').hasMatch(phone)) {
      _showError('Please enter a valid phone number.');
      return false;
    }

    if (_clientType == null) {
      _showError('Please select a client type.');
      return false;
    }

    return true;
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Submit form data to backend
  Future<void> _submit() async {
    if (!_validateForm()) return;

    setState(() => _loading = true);
    try {
      final vendorId = await _currentVendorId();
      final payload = {
        'schoolName': _schoolNameCtrl.text.trim(),
        'vendorId': vendorId,
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'contactName': _contactNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gstNumber': _gstNumberCtrl.text.trim(),
        'gstName': _gstNameCtrl.text.trim(),
        'gstStateCode': _gstStateCodeCtrl.text.trim(),
        'gstAddress': _gstAddressCtrl.text.trim(),
        'deliveryMode': _deliveryMode,
        'busStop': _busStopCtrl.text.trim(),
        'route': _routeCtrl.text.trim(),
        'clientType': _clientType,
        'state': _state,
        'district': _district,
        'pincode': _pincodeCtrl.text.trim(),
        'schoolCode': _schoolUniqueIdCtrl.text.trim().toUpperCase(),
      };

      debugPrint('[AddClient] Submitting: $payload');

      await _dio().post(
        '$_kBaseUrl/api/vendor/clients',
        data: payload,
        options: Options(contentType: Headers.jsonContentType),
      );

      if (!mounted) return;
      _showSuccess('Client added successfully!');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.pop(true);
      });
    } on DioException catch (e) {
      debugPrint('[AddClient] DIO Error: $e');
      final serverMsg = e.response?.data is Map
          ? (e.response!.data['error'] ?? e.response!.data.toString())
          : null;
      final msg = serverMsg ??
          'Failed to add client. Check your connection and try again.';
      if (!mounted) return;
      _showError(msg);
    } catch (e) {
      debugPrint('[AddClient] Unexpected error: $e');
      if (!mounted) return;
      _showError('Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Get districts for selected state
  List<String> _getDistrictsForState(String? state) {
    if (state == null) return [];
    return _districtsByState[state] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Client'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Section: School Information --------------------------------
              _SectionHeader(title: 'School Information'),
              const SizedBox(height: 16),
              AppTextField(
                label: 'School Name *',
                hint: 'e.g. Delhi Public School',
                prefixIcon: const Icon(Icons.school_rounded),
                controller: _schoolNameCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Address',
                hint: 'Street address',
                prefixIcon: const Icon(Icons.location_on_rounded),
                controller: _addressCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'City',
                hint: 'City name',
                prefixIcon: const Icon(Icons.location_city_rounded),
                controller: _cityCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'School Unique ID',
                hint: 'Optional unique identifier',
                prefixIcon: const Icon(Icons.fingerprint_rounded),
                controller: _schoolUniqueIdCtrl,
              ),

              const SizedBox(height: 24),
              // --- Section: Contact Person --------------------------------
              _SectionHeader(title: 'Contact Person'),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Contact Name',
                hint: 'Principal / Admin name',
                prefixIcon: const Icon(Icons.person_rounded),
                controller: _contactNameCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Phone Number *',
                hint: '+91 xxxxx xxxxx',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_rounded),
                controller: _phoneCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Email',
                hint: 'school@email.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_rounded),
                controller: _emailCtrl,
              ),

              const SizedBox(height: 24),
              // --- Section: Type --------------------------------
              _SectionHeader(title: 'Client Type *'),
              const SizedBox(height: 12),
              _RadioSection(
                options: const [
                  ('School', 'School Institution'),
                  ('Coaching', 'Coaching Center'),
                  ('Other', 'Other Organization'),
                ],
                value: _clientType,
                onChanged: (v) => setState(() => _clientType = v),
              ),

              const SizedBox(height: 24),
              // --- Section: GST Details --------------------------------
              _SectionHeader(title: 'GST Details'),
              const SizedBox(height: 16),
              AppTextField(
                label: 'GST Number',
                hint: '22ABCDE1234F1Z5',
                prefixIcon: const Icon(Icons.article_rounded),
                controller: _gstNumberCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'GST Name',
                hint: 'Name registered with GST',
                controller: _gstNameCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'GST State Code',
                hint: 'e.g. 07 (Delhi)',
                keyboardType: TextInputType.number,
                controller: _gstStateCodeCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'GST Address',
                hint: 'Registered GST address',
                maxLines: 2,
                controller: _gstAddressCtrl,
              ),

              const SizedBox(height: 24),
              // --- Section: Location Details --------------------------------
              _SectionHeader(title: 'Location Details'),
              const SizedBox(height: 16),
              SearchableSelectField(
                label: 'State',
                hint: 'Select State',
                value: _state,
                options: _states,
                prefixIcon: const Icon(Icons.map_rounded),
                validator: (v) => null,
                onSelected: (v) {
                  setState(() {
                    _state = v;
                    _district = null; // reset district when state changes
                  });
                },
              ),
              const SizedBox(height: 12),
              SearchableSelectField(
                label: 'District',
                hint: _state == null ? 'Select State first' : 'Select District',
                value: _district,
                options: _getDistrictsForState(_state),
                enabled: _state != null,
                prefixIcon: const Icon(Icons.location_city_rounded),
                validator: (v) => null,
                onSelected: (v) => setState(() => _district = v),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Pincode',
                hint: '110001',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.pin_drop_rounded),
                controller: _pincodeCtrl,
              ),

              const SizedBox(height: 24),
              // --- Section: Delivery & Transport --------------------------------
              _SectionHeader(title: 'Delivery Mode'),
              const SizedBox(height: 12),
              _RadioSection(
                options: const [
                  ('Bus', 'Delivery by Bus'),
                  ('Courier', 'Delivery by Courier'),
                ],
                value: _deliveryMode,
                onChanged: (v) => setState(() => _deliveryMode = v),
              ),
              const SizedBox(height: 12),
              if (_deliveryMode == 'Bus') ...[
                AppTextField(
                  label: 'Bus Stop',
                  hint: 'Nearest bus stop for delivery',
                  prefixIcon: const Icon(Icons.directions_bus_rounded),
                  controller: _busStopCtrl,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Route',
                  hint: 'Bus route number / name',
                  prefixIcon: const Icon(Icons.route_rounded),
                  controller: _routeCtrl,
                ),
              ],

              const SizedBox(height: 32),
              // --- Submit Button --------------------------------
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: 'Add Client',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Custom Radio Section Widget
class _RadioSection extends StatelessWidget {
  final List<(String value, String label)> options;
  final String? value;
  final Function(String?) onChanged;

  const _RadioSection({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((option) {
        final isSelected = value == option.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.grey.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RadioListTile<String>(
              value: option.$1,
              groupValue: value,
              onChanged: onChanged,
              title: Text(
                option.$2,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// -------------------------------------------------------------------
// CLIENT DETAILS
// -------------------------------------------------------------------
class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailsScreen({super.key, required this.clientId});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  static const _kBaseUrl = _kServerBase;

  bool _loading = true;
  Map<String, dynamic>? _client;
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _schoolSummary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _confirmDelete() async {
    final name = _client?['schoolName'] as String? ?? 'this client';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text(
            'Delete "$name"? All their orders will remain but the client will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _dio().delete('$_kBaseUrl/api/vendor/clients/${widget.clientId}');
      if (!mounted) return;
      context.pop(true); // signals ClientListScreen to reload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to delete client.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dio = _dio();
      final results = await Future.wait([
        dio.get('$_kBaseUrl/api/vendor/clients/${widget.clientId}'),
        dio.get('$_kBaseUrl/api/vendor/clients/${widget.clientId}/orders'),
        dio.get(
            '$_kBaseUrl/api/vendor/clients/${widget.clientId}/school-summary'),
      ]);
      if (!mounted) return;
      setState(() {
        _client = results[0].data as Map<String, dynamic>;
        _orders = (results[1].data as List).cast<Map<String, dynamic>>();
        _schoolSummary = results[2].data is Map
            ? Map<String, dynamic>.from(results[2].data as Map)
            : null;
        debugPrint('[ClientDetail] schoolSummary: $_schoolSummary');
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[ClientDetail] load error: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _editSchoolCode() async {
    final currentCode = (_client?['schoolCode'] as String? ?? '').toUpperCase();
    final ctrl = TextEditingController(text: currentCode);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set School Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the school code that links this client to a principal account. This is required for Excel data to be saved under the correct school.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'School Code',
                hintText: 'e.g. ABC123',
                prefixIcon: Icon(Icons.fingerprint_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(ctrl.text.trim().toUpperCase()),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    try {
      await _dio().patch(
        '$_kBaseUrl/api/vendor/clients/${widget.clientId}',
        data: {'schoolCode': result},
        options: Options(contentType: Headers.jsonContentType),
      );
      await _loadData(); // refresh all data including school summary
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update school code: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _client?['schoolName'] as String? ?? 'Client #${widget.clientId}';
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Loading�' : name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateOrderScreen(
                  preselectedClient: {
                    ...?_client,
                    'id': widget.clientId,
                    'schoolName': _client?['schoolName'] ?? '',
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client hero card
                  GradientCard(
                    gradient: AppColors.primaryGradient,
                    child: Row(
                      children: [
                        AppAvatar(name: name, radius: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: AppTypography.titleSmall
                                      .copyWith(color: Colors.white)),
                              if ((_client?['city'] as String? ?? '')
                                  .isNotEmpty)
                                Text(
                                  _client!['city'] as String,
                                  style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.7)),
                                ),
                              if ((_client?['clientType'] as String? ?? '')
                                  .isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _client!['clientType'] as String,
                                    style: AppTypography.caption
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Details section
                  _ClientInfoSection(client: _client!),
                  const SizedBox(height: 20),

                  // ── School Data Summary ────────────────────────
                  if (_schoolSummary != null &&
                      _schoolSummary!['linked'] == true) ...[
                    _SchoolDataSummaryCard(
                      summary: _schoolSummary!,
                      onRefresh: _loadData,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateOrderScreen(
                                preselectedClient: {
                                  ...?_client,
                                  'id': widget.clientId,
                                  'schoolName': _client?['schoolName'] ?? '',
                                },
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add_box_rounded, size: 18),
                          label: const Text('Create Order'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go('/vendor/clients/${widget.clientId}'),
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('View Orders'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SectionHeader(
                    title: 'Order History',
                    action: 'New Order',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateOrderScreen(
                          preselectedClient: {
                            ...?_client,
                            'id': widget.clientId,
                            'schoolName': _client?['schoolName'] ?? '',
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_orders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No order history available',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._orders.map((order) {
                      final stage = order['stage'] as String? ?? 'Draft';
                      final progress = (order['progress'] as num? ?? 0).toInt();
                      return PremiumCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        onTap: () => context.go('/vendor/project-board/$stage'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order['title'] as String? ??
                                        'Untitled Order',
                                    style: AppTypography.labelLarge,
                                  ),
                                ),
                                RoleBadge(
                                    label: stage, color: AppColors.primary),
                              ],
                            ),
                            if ((order['productType'] as String? ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(order['productType'] as String,
                                  style: AppTypography.bodySmall),
                            ],
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100.0,
                                minHeight: 5,
                                color: AppColors.primary,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.1),
                              ),
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

// -------------------------------------------------------------------
// SCHOOL DATA SUMMARY CARD (shown in ClientDetailsScreen)
// -------------------------------------------------------------------
class _SchoolDataSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final VoidCallback onRefresh;
  const _SchoolDataSummaryCard(
      {required this.summary, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final classes = summary['classesCount'] as int? ?? 0;
    final students = summary['studentsCount'] as int? ?? 0;
    final teachers = summary['teachersCount'] as int? ?? 0;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('School Data',
                    style: AppTypography.titleSmall
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh',
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SchoolStatChip(
                icon: Icons.class_rounded,
                label: 'Classes',
                value: '$classes',
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              _SchoolStatChip(
                icon: Icons.school_rounded,
                label: 'Students',
                value: '$students',
                color: Colors.teal,
              ),
              const SizedBox(width: 10),
              _SchoolStatChip(
                icon: Icons.person_rounded,
                label: 'Teachers',
                value: '$teachers',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchoolStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SchoolStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.titleSmall
                  .copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// CLIENT INFO SECTION  (used inside ClientDetailsScreen)
// -------------------------------------------------------------------
class _ClientInfoSection extends StatelessWidget {
  final Map<String, dynamic> client;
  const _ClientInfoSection({required this.client});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[];

    final schoolCode = client['schoolCode'] as String? ?? '';
    if (schoolCode.isNotEmpty) {
      rows.add(_InfoRow(
          icon: Icons.fingerprint_rounded,
          label: 'School Code',
          value: schoolCode));
    }

    final contact = client['contactName'] as String? ?? '';
    if (contact.isNotEmpty) {
      rows.add(_InfoRow(
          icon: Icons.person_rounded, label: 'Contact Person', value: contact));
    }

    final phone = client['phone'] as String? ?? '';
    if (phone.isNotEmpty) {
      rows.add(
          _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: phone));
    }

    final email = client['email'] as String? ?? '';
    if (email.isNotEmpty) {
      rows.add(
          _InfoRow(icon: Icons.email_rounded, label: 'Email', value: email));
    }

    final address = client['address'] as String? ?? '';
    if (address.isNotEmpty) {
      rows.add(_InfoRow(
          icon: Icons.location_on_rounded, label: 'Address', value: address));
    }

    final city = client['city'] as String? ?? '';
    final state = client['state'] as String? ?? '';
    final district = client['district'] as String? ?? '';
    final pincode = client['pincode'] as String? ?? '';
    final locationParts = [
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
      if (state.isNotEmpty) state,
      if (pincode.isNotEmpty) pincode,
    ];
    if (locationParts.isNotEmpty) {
      rows.add(_InfoRow(
          icon: Icons.map_rounded,
          label: 'Location',
          value: locationParts.join(', ')));
    }

    final deliveryMode = client['deliveryMode'] as String? ?? '';
    if (deliveryMode.isNotEmpty) {
      rows.add(_InfoRow(
          icon: Icons.local_shipping_rounded,
          label: 'Delivery Mode',
          value: deliveryMode));
    }

    final gst = client['gstNumber'] as String? ?? '';
    if (gst.isNotEmpty) {
      rows.add(_InfoRow(
          icon: Icons.article_rounded, label: 'GST Number', value: gst));
    }

    final createdAt = client['createdAt'] as String? ?? '';
    if (createdAt.isNotEmpty) {
      String displayDate = createdAt;
      try {
        final dt = DateTime.parse(createdAt);
        displayDate = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
      rows.add(_InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Joined',
          value: displayDate));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Text('Client Details',
                style: AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(r.icon, color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.label,
                              style: AppTypography.caption.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5))),
                          const SizedBox(height: 2),
                          Text(r.value, style: AppTypography.labelMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
}

// -------------------------------------------------------------------
// CREATE ORDER
// -------------------------------------------------------------------
class CreateOrderScreen extends StatefulWidget {
  final Map<String, dynamic>? preselectedClient;
  const CreateOrderScreen({super.key, this.preselectedClient});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  static const _kBaseUrl = _kServerBase;

  int _step = 0;
  bool _loading = false;

  // -- Form data -------------------------------------------------
  final _titleCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  // -- Product catalogue state
  Product? _selectedProduct;
  List<Product> _products = [];
  bool _loadingProducts = true;

  // -- Step 1: Client selection & date state ---------------------
  String? _selectedClientId;
  String _selectedClientName = '';
  String _selectedClientSchoolCode = '';
  DateTime? _selectedDeliveryDate;

  @override
  void initState() {
    super.initState();
    final pre = widget.preselectedClient;
    if (pre != null) {
      _selectedClientId = pre['id']?.toString() ?? pre['_id']?.toString();
      _selectedClientSchoolCode =
          (pre['schoolCode']?.toString() ?? '').toUpperCase();
      _selectedClientName = pre['schoolName']?.toString() ?? '';
      _schoolCtrl.text = _selectedClientName;
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _dio().get(ApiConfig.vendorProducts);
      final data = (res.data as Map<String, dynamic>?)?['data'] as List?;
      if (data != null && mounted) {
        setState(() {
          _products = data
              .map((j) => Product.fromJson(j as Map<String, dynamic>))
              .toList();
          _loadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint('[CreateOrder] failed to load products: $e');
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  // -- Quantity -------------------------------------------------
  int _quantity = 1;
  final _quantityCtrl = TextEditingController(text: '1');
  String _unit = 'Pieces';

  // -- Lifted CSV/data-file state (persists across step navigation) ------
  String _dataFilePath = '';
  String _dataFileName = '';
  List<String> _dataFileHeaders = [];
  List<List<dynamic>> _excelData = [];

  // -- Step 2: Product config state ----------------------------
  List<_VarField> _variableFields = [];
  Map<String, String> _columnMappings = {};

  // -- Step 2: Attached design files ---------------------------------
  List<_OrderFile> _selectedFiles = [];

  // -- Step 3: Order images (saved to images[] in the order) ------------
  List<String> _orderImages = [];
  String _loadingMessage = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _schoolCtrl.dispose();
    _deliveryCtrl.dispose();
    _descriptionCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  // -- Linear 5-step flow: 0=Details, 1=Product, 2=Config, 3=Images, 4=Review/Submit
  Future<void> _handleContinue() async {
    if (_step == 0) {
      if (widget.preselectedClient == null &&
          (_selectedClientId == null || _selectedClientId!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a school'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      if (_selectedDeliveryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a delivery date'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a product to continue'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      setState(() => _step = 2);
    } else if (_step == 2) {
      // Auto-set quantity from Excel row count when entering the images step
      final rowCount = _excelData.length;
      setState(() {
        if (rowCount > 0) {
          _quantity = rowCount;
          _quantityCtrl.text = '$rowCount';
        }
        _step = 3;
      });
    } else if (_step == 3) {
      setState(() => _step = 4);
    } else {
      _submitOrder();
    }
  }

  Future<void> _submitOrder() async {
    setState(() => _loading = true);
    try {
      final vendorId = await _currentVendorId();

      // ── Upload attachments (design files) first ──────────────────────────
      List<String> uploadedAttachmentUrls = [];
      if (_selectedFiles.isNotEmpty) {
        if (mounted) setState(() => _loadingMessage = 'Uploading attachments…');
        uploadedAttachmentUrls =
            await _uploadAttachmentsToServer(_selectedFiles);
        debugPrint(
            '[CreateOrder] Uploaded attachment URLs: $uploadedAttachmentUrls');
      }

      // ── Upload order images ──────────────────────────────────────────────
      List<String> uploadedImageUrls = [];
      if (_orderImages.isNotEmpty) {
        if (mounted) setState(() => _loadingMessage = 'Uploading images…');
        uploadedImageUrls = await _uploadImagesToServer(_orderImages);
        debugPrint('[CreateOrder] Uploaded image URLs: $uploadedImageUrls');
        if (uploadedImageUrls.isEmpty && mounted) {
          // Upload failed — warn but continue creating the order
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Image upload failed — order will be created without images.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ));
        }
      }

      if (mounted) setState(() => _loadingMessage = 'Creating order…');

      final projectName = _titleCtrl.text.trim().isEmpty
          ? 'Untitled Order'
          : _titleCtrl.text.trim();
      final schoolName = _selectedClientName.isNotEmpty
          ? _selectedClientName
          : _schoolCtrl.text.trim();

      final payload = {
        'name': projectName,
        'title': projectName,
        'client': schoolName,
        'schoolName': schoolName,
        'clientId': _selectedClientId,
        'schoolCode': _selectedClientSchoolCode.isNotEmpty
            ? _selectedClientSchoolCode
            : null,
        'productId': _selectedProduct?.id,
        'productType': _selectedProduct?.category ?? 'general',
        'productName': _selectedProduct?.name,
        'productImage': _selectedProduct?.image,
        'variableFields': _variableFields
            .where((f) => f.key.trim().isNotEmpty)
            .map((f) => {'name': f.key.trim(), 'type': f.type})
            .toList(),
        'columnMappings': _columnMappings,
        'quantity': _quantity,
        'unit': _unit,
        'excelData': _excelData,
        'excelHeaders': _dataFileHeaders,
        'excelFileName': _dataFileName.isEmpty ? null : _dataFileName,
        'attachmentUrls': uploadedAttachmentUrls,
        'deliveryDate': _selectedDeliveryDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate!)
            : null,
        'description': _descriptionCtrl.text.trim(),
        'status': 'draft',
        'stage': 'draft',
        'vendorId': vendorId,
        'orderImages': uploadedImageUrls,
      };

      debugPrint('[CreateOrder] → POST $_kBaseUrl/api/projects');
      debugPrint('[CreateOrder]   payload: $payload');

      Response<dynamic> response;
      try {
        response = await _dio().post(
          '$_kBaseUrl/api/projects',
          data: payload,
          options: Options(
            validateStatus: (status) => status != null && status < 600,
          ),
        );
      } on DioException catch (dioErr) {
        final msg = dioErr.response?.data?['error']?.toString() ??
            dioErr.message ??
            'Network error';
        debugPrint('[CreateOrder] DioException: $msg');
        debugPrint('[CreateOrder] DioException detail: $dioErr');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create order: $msg'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      debugPrint('[CreateOrder] ← ${response.statusCode} ${response.data}');

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        final errMsg = (response.data is Map)
            ? (response.data['error'] ??
                response.data['message'] ??
                'Server error $statusCode')
            : 'Server error $statusCode';
        debugPrint('[CreateOrder] Backend error: $errMsg');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create order: $errMsg'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final projectId =
          (response.data as Map<String, dynamic>?)?['id']?.toString();
      debugPrint('[CreateOrder] Created project id=$projectId');
      if (!mounted) return;
      // Files were already uploaded BEFORE order creation — no post-upload needed.
      // Removing the old _uploadOrderFiles call that caused race conditions and
      // used localhost:5001 URLs which broke on physical device.
      context.go('/vendor/project-board');
    } catch (e, st) {
      debugPrint('[CreateOrder] Unexpected error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to create order: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _loadingMessage = '';
        });
    }
  }

  /// Upload attached design files (PDFs, images, CDR, etc.) BEFORE order creation.
  /// Uses POST /api/projects/upload-attachments  →  field: "files"  →  response: { urls }
  Future<List<String>> _uploadAttachmentsToServer(
      List<_OrderFile> files) async {
    if (files.isEmpty) return [];
    try {
      final uploadDio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 60),
      ));
      final formData = FormData();
      for (final f in files) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(f.path, filename: f.name),
        ));
      }
      debugPrint('[CreateOrder] Uploading ${files.length} attachment(s) to '
          '$_kServerBase/api/projects/upload-attachments');
      final res = await uploadDio.post(
        '$_kServerBase/api/projects/upload-attachments',
        data: formData,
      );
      debugPrint(
          '[CreateOrder] upload-attachments ${res.statusCode}: ${res.data}');
      if (res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300) {
        final urls = (res.data is Map ? (res.data['urls'] as List?) : null)
            ?.cast<String>();
        return urls ?? [];
      }
      debugPrint('[CreateOrder] upload-attachments non-2xx: ${res.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[CreateOrder] upload-attachments error: $e');
      return [];
    }
  }

  /// Upload order images BEFORE order creation.
  /// Uses POST /api/projects/upload-images  →  field: "images"  →  response: { imageUrls }
  Future<List<String>> _uploadImagesToServer(List<String> localPaths) async {
    if (localPaths.isEmpty) return [];
    try {
      final uploadDio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 60),
      ));
      final formData = FormData();
      for (final p in localPaths) {
        final name = p.replaceAll('\\', '/').split('/').last;
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(p, filename: name),
        ));
      }
      debugPrint('[CreateOrder] Uploading ${localPaths.length} image(s) to '
          '$_kServerBase/api/projects/upload-images');
      final res = await uploadDio.post(
        '$_kServerBase/api/projects/upload-images',
        data: formData,
      );
      debugPrint('[CreateOrder] upload-images ${res.statusCode}: ${res.data}');
      if (res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300) {
        // endpoint returns { imageUrls: [...] }
        final urls = (res.data is Map ? (res.data['imageUrls'] as List?) : null)
            ?.cast<String>();
        return urls ?? [];
      }
      debugPrint('[CreateOrder] upload-images non-2xx: ${res.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[CreateOrder] upload-images error: $e');
      return [];
    }
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _Step1(
          titleCtrl: _titleCtrl,
          schoolCtrl: _schoolCtrl,
          deliveryCtrl: _deliveryCtrl,
          selectedDeliveryDate: _selectedDeliveryDate,
          isPreselected: widget.preselectedClient != null,
          preselectedName: widget.preselectedClient?['schoolName']?.toString(),
          preselectedClientId: _selectedClientId,
          onClientResolved: (clientId, schoolName, schoolCode) {
            setState(() {
              _selectedClientId = clientId;
              _selectedClientName = schoolName ?? '';
              _selectedClientSchoolCode = schoolCode ?? '';
              if (schoolName != null) _schoolCtrl.text = schoolName;
            });
          },
          onDeliveryDateSelected: (date) {
            setState(() {
              _selectedDeliveryDate = date;
              _deliveryCtrl.text = DateFormat('dd/MM/yyyy').format(date);
            });
          },
        );
      case 1:
        return _InlineProductSelect(
          products: _products,
          loading: _loadingProducts,
          selectedProduct: _selectedProduct,
          onSelect: (p) => setState(() => _selectedProduct = p),
          onRefresh: _loadProducts,
        );
      case 2:
        return _Step2(
          attachedFiles: _selectedFiles,
          onFilesChanged: (files) => setState(() => _selectedFiles = files),
          changesDescCtrl: _descriptionCtrl,
          variableFields: _variableFields,
          onVariableFieldsChanged: (fields) =>
              setState(() => _variableFields = fields),
          columnMappings: _columnMappings,
          onColumnMappingsChanged: (map) =>
              setState(() => _columnMappings = map),
          productCategory: _selectedProduct?.category ?? 'general',
          dataFilePath: _dataFilePath,
          dataFileName: _dataFileName,
          dataFileHeaders: _dataFileHeaders,
          excelData: _excelData,
          onDataFileChanged: (path, name, headers, rows) => setState(() {
            _dataFilePath = path;
            _dataFileName = name;
            _dataFileHeaders = headers;
            _excelData = rows;
          }),
        );
      case 3:
        return _Step3(
          selectedFiles: const [],
          descriptionCtrl: _descriptionCtrl,
          onFilesChanged: (_) {},
          orderImages: _orderImages,
          onOrderImagesChanged: (imgs) => setState(() => _orderImages = imgs),
          quantityCtrl: _quantityCtrl,
          onQuantityChanged: (q) => setState(() => _quantity = q),
          excelRowCount: _excelData.length,
          unit: _unit,
          onUnitChanged: (u) => setState(() => _unit = u),
        );
      default:
        return _Step4(
          title: _titleCtrl.text.trim().isEmpty ? '-' : _titleCtrl.text.trim(),
          school:
              _schoolCtrl.text.trim().isEmpty ? '-' : _schoolCtrl.text.trim(),
          product: _selectedProduct?.name ?? 'Not selected',
          deliveryDate: _deliveryCtrl.text.trim().isEmpty
              ? '-'
              : _deliveryCtrl.text.trim(),
          quantity: _quantity,
          unit: _unit,
          description: _descriptionCtrl.text.trim(),
          fileCount: _selectedFiles.length,
          imageCount: _orderImages.length,
          csvFileName: _dataFileName,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: Column(
        children: [
          // Step indicator (5 steps)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(5, (i) {
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: i < _step
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : Text('${i + 1}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: i <= _step
                                        ? Colors.white
                                        : AppColors.primary,
                                  )),
                        ),
                      ),
                      if (i < 4)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i < _step
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.15),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCurrentStep(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loadingMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _loadingMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.deepOrange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        label: _step < 4 ? 'Continue' : 'Create Order',
                        loading: _loading,
                        onPressed: _handleContinue,
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

// ── Inline Product Selection (Step 2) ────────────────────────────────────────

class _InlineProductSelect extends StatelessWidget {
  final List<Product> products;
  final bool loading;
  final Product? selectedProduct;
  final ValueChanged<Product> onSelect;
  final VoidCallback onRefresh;

  const _InlineProductSelect({
    required this.products,
    required this.loading,
    required this.selectedProduct,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (products.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No products found',
                  style: AppTypography.titleSmall
                      .copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select a Product', style: AppTypography.titleMedium),
        const SizedBox(height: 4),
        Text('Choose the product for this order',
            style:
                AppTypography.bodySmall.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            final selected = selectedProduct?.id == p.id;
            final imageUrl =
                p.images.isNotEmpty ? p.images.first : p.thumbnailImage;
            final price = p.priceForRole('vendor');
            return GestureDetector(
              onTap: () => onSelect(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.07)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : Colors.grey.withOpacity(0.2),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    ApiConfig.resolveImageUrl(imageUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder(),
                                    loadingBuilder: (_, child, progress) =>
                                        progress == null
                                            ? child
                                            : const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2)),
                                  )
                                : _imgPlaceholder(),
                            // Info button — opens detail screen
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.of(context)
                                      .push<Product>(MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                        product: p, role: 'vendor'),
                                  ));
                                  if (result != null) onSelect(result);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.info_outline_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: selected ? AppColors.primary : null,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 18),
                        ],
                      ),
                    ),
                    if (price > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 8),
                        child: Text(
                          '₹${price.toStringAsFixed(0)} / card',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.secondary),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child:
            Icon(Icons.image_outlined, size: 36, color: Colors.grey.shade400),
      ),
    );
  }
}

// ── Step 1 ────────────────────────────────────────────────────────────────────

class _Step1 extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController schoolCtrl;
  final TextEditingController deliveryCtrl;
  final DateTime? selectedDeliveryDate;
  final bool isPreselected;
  final String? preselectedName;
  final String? preselectedClientId;
  final void Function(String? clientId, String? schoolName, String? schoolCode)
      onClientResolved;
  final void Function(DateTime date) onDeliveryDateSelected;

  const _Step1({
    required this.titleCtrl,
    required this.schoolCtrl,
    required this.deliveryCtrl,
    required this.selectedDeliveryDate,
    required this.isPreselected,
    this.preselectedName,
    this.preselectedClientId,
    required this.onClientResolved,
    required this.onDeliveryDateSelected,
  });

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  List<Client> _clients = [];
  bool _loadingClients = true;
  Client? _selectedClient;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final res = await _dio().get('$_kServerBase/api/clients');
      if (!mounted) return;
      final list = (res.data as List?)
              ?.map((j) => Client.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [];
      setState(() {
        _clients = list;
        _loadingClients = false;
        // Pre-select if a client was already chosen (e.g. preselected or revisiting)
        if (widget.preselectedClientId != null) {
          _selectedClient = _clients.cast<Client?>().firstWhere(
                (c) => c?.id == widget.preselectedClientId,
                orElse: () => null,
              );
        }
      });
    } catch (e) {
      debugPrint('[Step1] loadClients error: $e');
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      widget.onDeliveryDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Order for:" banner when client is pre-selected
        if (widget.isPreselected) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order for',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          )),
                      Text(
                        widget.preselectedName ?? widget.schoolCtrl.text,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text('Order Details', style: AppTypography.titleSmall),
        const SizedBox(height: 16),

        // Order Title
        AppTextField(
          label: 'Order Title',
          hint: 'e.g. ID Cards - Batch 2025',
          controller: widget.titleCtrl,
        ),
        const SizedBox(height: 12),

        // School dropdown (hidden when client is pre-selected via navigation)
        if (!widget.isPreselected) ...[
          if (_loadingClients)
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withOpacity(0.04),
              ),
              child: const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            DropdownButtonFormField<Client>(
              value: _selectedClient,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select School',
                hintText: 'Choose a school',
                prefixIcon: Icon(Icons.school_rounded,
                    color: AppColors.primary.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.04),
              ),
              items: _clients
                  .map((c) => DropdownMenuItem<Client>(
                        value: c,
                        child: Text(c.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium),
                      ))
                  .toList(),
              onChanged: (client) {
                setState(() => _selectedClient = client);
                if (client != null) {
                  widget.onClientResolved(
                      client.id, client.name, client.schoolCode);
                } else {
                  widget.onClientResolved(null, null, null);
                }
              },
              validator: (value) =>
                  value == null ? 'Please select a school' : null,
            ),
          const SizedBox(height: 12),
        ],

        // Expected Delivery with Calendar Picker
        TextFormField(
          controller: widget.deliveryCtrl,
          readOnly: true,
          onTap: () => _selectDate(context),
          decoration: InputDecoration(
            labelText: 'Expected Delivery',
            hintText: 'Tap to select date',
            prefixIcon: Icon(Icons.calendar_today_rounded,
                color: AppColors.primary.withOpacity(0.7)),
            suffixIcon: widget.selectedDeliveryDate != null
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppColors.primary.withOpacity(0.04),
          ),
          style: AppTypography.bodyMedium,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a delivery date';
            }
            return null;
          },
        ),

        // Helper text showing selected date range
        if (widget.selectedDeliveryDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.primary.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  'Delivery scheduled for ${DateFormat('EEE, MMM d, yyyy').format(widget.selectedDeliveryDate!)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Step2 extends StatefulWidget {
  final List<_OrderFile> attachedFiles;
  final void Function(List<_OrderFile>) onFilesChanged;
  final TextEditingController changesDescCtrl;
  final List<_VarField> variableFields;
  final void Function(List<_VarField>) onVariableFieldsChanged;
  final Map<String, String> columnMappings;
  final void Function(Map<String, String>) onColumnMappingsChanged;

  /// Product template category — drives which fields appear in the mapping grid.
  final String productCategory;

  // Lifted CSV/data-file state (owned by parent so it survives step navigation)
  final String dataFilePath;
  final String dataFileName;
  final List<String> dataFileHeaders;
  final List<List<dynamic>> excelData;
  final void Function(
    String path,
    String name,
    List<String> headers,
    List<List<dynamic>> rows,
  ) onDataFileChanged;

  const _Step2({
    required this.attachedFiles,
    required this.onFilesChanged,
    required this.changesDescCtrl,
    required this.variableFields,
    required this.onVariableFieldsChanged,
    required this.columnMappings,
    required this.onColumnMappingsChanged,
    this.productCategory = 'general',
    this.dataFilePath = '',
    this.dataFileName = '',
    this.dataFileHeaders = const [],
    this.excelData = const [],
    required this.onDataFileChanged,
  });

  @override
  State<_Step2> createState() => _Step2State();
}

/// A custom field defined by the vendor in "Variable Fields".
class _VarField {
  String key;
  String type; // 'text' | 'number' | 'image'
  _VarField({this.key = '', this.type = 'text'});
}

class _Step2State extends State<_Step2> {
  bool _isPickingFiles = false;

  // ── Data-file upload (Excel / CSV for column mapping) ────────────
  bool _isPickingDataFile = false;
  bool _parsingDataFile = false;
  String? _dataFileError;

  // Getters that forward to lifted parent state (survives step navigation)
  String get _dataFilePath => widget.dataFilePath;
  String get _dataFileName => widget.dataFileName;
  List<String> get _dataFileHeaders => widget.dataFileHeaders;

  Future<void> _pickDataFile() async {
    setState(() {
      _isPickingDataFile = true;
      _dataFileError = null;
    });
    FilePickerResult? result;
    try {
      result = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isPickingDataFile = false;
          _dataFileError = 'Could not open file picker: $e';
        });
      return;
    }
    setState(() => _isPickingDataFile = false);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final ext = file.name.split('.').last.toLowerCase();
    if (!['xlsx', 'xls', 'csv'].contains(ext)) {
      if (mounted)
        setState(() => _dataFileError =
            'Unsupported type ".$ext". Use .xlsx, .xls or .csv.');
      return;
    }
    if (file.path == null) {
      if (mounted)
        setState(() => _dataFileError = 'Could not read file path. Try again.');
      return;
    }

    setState(() => _parsingDataFile = true);
    try {
      final headers = await compute(parseHeadersCompute, file.path!);
      final allRows = await compute(parsePreviewCompute, file.path!);
      if (mounted) {
        setState(() => _parsingDataFile = false);
        widget.onDataFileChanged(file.path!, file.name, headers, allRows);
        // Auto-map: each Excel column header maps to itself by default
        final autoMap = <String, String>{
          for (final h in headers) h: h,
        };
        widget.onColumnMappingsChanged(autoMap);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _parsingDataFile = false;
          _dataFileError = 'Could not read headers: $e';
        });
      }
    }
  }

  // ── Per-template field definitions ───────────────────────────────
  //  Each product category drives which fields appear in the mapping grid.
  static const _kFieldSets = <String, List<String>>{
    'id_card': [
      'Student Name',
      'Class',
      'Section',
      'Roll / Adm No.',
      'Date of Birth',
      'Blood Group',
      'Parent Name',
      'Phone',
      'Address',
      'Photo Filename',
    ],
    'report_card': [
      'Student Name',
      'Class',
      'Section',
      'Roll / Adm No.',
      'Subject 1',
      'Subject 2',
      'Subject 3',
      'Subject 4',
      'Subject 5',
      'Total Marks',
      'Percentage',
      'Grade',
      'Class Teacher',
    ],
    'badge': [
      'Student Name',
      'Class',
      'Achievement',
      'Sport / Activity',
      'Year',
    ],
    'trophy': [
      'Recipient Name',
      'Event',
      'Category',
      'Position',
      'Date',
    ],
    'general': [
      'Name',
      'Roll No.',
      'Class / Section',
      'Phone',
      'Address',
      'Date of Birth',
      'Parent Name',
      'Blood Group',
    ],
  };

  List<String> get _activeFields {
    // When Excel is loaded, use its headers as the primary field list
    if (_dataFileHeaders.isNotEmpty) {
      final customNames = widget.variableFields
          .map((f) => f.key.trim())
          .where((k) => k.isNotEmpty && !_dataFileHeaders.contains(k))
          .toList();
      return [..._dataFileHeaders, ...customNames];
    }

    // No Excel loaded: fall back to template-based presets
    final cat = widget.productCategory.toLowerCase().trim();
    List<String> base;
    if (cat.contains('id') && cat.contains('card'))
      base = _kFieldSets['id_card']!;
    else if (cat.contains('report'))
      base = _kFieldSets['report_card']!;
    else if (cat.contains('badge'))
      base = _kFieldSets['badge']!;
    else if (cat.contains('trophy'))
      base = _kFieldSets['trophy']!;
    else
      base = _kFieldSets[cat] ?? _kFieldSets['general']!;

    // Append any custom fields added in "Variable Fields" that have a name
    final customNames = widget.variableFields
        .map((f) => f.key.trim())
        .where((k) => k.isNotEmpty && !base.contains(k))
        .toList();
    if (customNames.isEmpty) return base;
    return [...base, ...customNames];
  }

  // ── File picking ────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    setState(() => _isPickingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'cdr',
          'ai',
          'psd',
          'eps',
          'svg',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
        final added = result.files.where((f) => f.path != null).map((f) {
          final ext = f.extension?.toLowerCase() ?? '';
          return _OrderFile(
            path: f.path!,
            name: f.name,
            isImage: imageExts.contains(ext),
          );
        }).toList();
        widget.onFilesChanged([...widget.attachedFiles, ...added]);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isPickingFiles = false);
    }
  }

  void _removeFile(int index) {
    final updated = List<_OrderFile>.from(widget.attachedFiles)
      ..removeAt(index);
    widget.onFilesChanged(updated);
  }

  // ── Variable fields helpers ──────────────────────────────────────

  void _addVarField() {
    final updated = [...widget.variableFields, _VarField()];
    widget.onVariableFieldsChanged(updated);
  }

  void _removeVarField(int index) {
    final updated = List<_VarField>.from(widget.variableFields)
      ..removeAt(index);
    widget.onVariableFieldsChanged(updated);
  }

  void _updateVarFieldKey(int index, String key) {
    final updated = List<_VarField>.from(widget.variableFields);
    updated[index] = _VarField(key: key, type: updated[index].type);
    widget.onVariableFieldsChanged(updated);
  }

  void _updateVarFieldType(int index, String type) {
    final updated = List<_VarField>.from(widget.variableFields);
    updated[index] = _VarField(key: updated[index].key, type: type);
    widget.onVariableFieldsChanged(updated);
  }

  // ── File picking ────────────────────────────────────────────────

  IconData _iconForFile(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'cdr':
      case 'ai':
      case 'psd':
      case 'eps':
      case 'svg':
        return Icons.palette_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForFile(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'cdr':
      case 'ai':
      case 'psd':
      case 'eps':
      case 'svg':
        return Colors.deepOrange;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  // ── Section header ───────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style:
                AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = widget.attachedFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ────────────────────────────────────────────────────────────
        // 1. ATTACH FILES
        // ────────────────────────────────────────────────────────────
        _sectionHeader(
            'Attach Files', Icons.attach_file_rounded, AppColors.primary),
        const SizedBox(height: 12),

        // Upload trigger card
        GestureDetector(
          onTap: _isPickingFiles ? null : _pickFiles,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: AppColors.primary.withOpacity(0.03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isPickingFiles)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isPickingFiles ? 'Selecting…' : 'Select Files',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text('PDF • Images • CDR • XLSX',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.secondary.withOpacity(0.55))),
              ],
            ),
          ),
        ),

        // File list
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(files.length, (i) {
                final f = files[i];
                final color =
                    f.isImage ? AppColors.primary : _colorForFile(f.name);
                return Container(
                  decoration: BoxDecoration(
                    border: i < files.length - 1
                        ? Border(
                            bottom: BorderSide(
                                color: theme.dividerColor.withOpacity(0.3)))
                        : null,
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: f.isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(f.path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.image_rounded,
                                    color: color,
                                    size: 18),
                              ),
                            )
                          : Icon(_iconForFile(f.name), color: color, size: 18),
                    ),
                    title: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      f.isImage
                          ? 'Image'
                          : f.name.split('.').last.toUpperCase(),
                      style: AppTypography.caption
                          .copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                    trailing: GestureDetector(
                      onTap: () => _removeFile(i),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.09),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.red, size: 14),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              '${files.length} file${files.length == 1 ? '' : 's'} attached',
              style: AppTypography.caption.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ────────────────────────────────────────────────────────────
        // 2. DESCRIBE REQUIRED CHANGES
        // ────────────────────────────────────────────────────────────
        _sectionHeader('Describe Required Changes', Icons.edit_note_rounded,
            AppColors.secondary),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.changesDescCtrl,
          maxLines: 6,
          minLines: 4,
          decoration: InputDecoration(
            hintText:
                'Describe the changes or customisations needed for this order…',
            hintStyle: AppTypography.bodySmall
                .copyWith(color: theme.colorScheme.onSurface.withOpacity(0.38)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: AppColors.secondary.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: AppColors.secondary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.secondary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.secondary.withOpacity(0.04),
            contentPadding: const EdgeInsets.all(14),
          ),
          style: AppTypography.bodyMedium,
        ),

        const SizedBox(height: 28),

        // ────────────────────────────────────────────────────────────
        // 3. VARIABLE FIELDS
        // ────────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _sectionHeader(
                  'Variable Fields', Icons.tune_rounded, Colors.teal),
            ),
            TextButton.icon(
              onPressed: _addVarField,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Add Field'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Quick-add chips from Excel headers ─────────────────────────
        if (_dataFileHeaders.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.teal.withOpacity(0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_chart_rounded,
                        color: Colors.teal, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Excel columns — tap to add as variable field:',
                      style: AppTypography.caption.copyWith(
                          color: Colors.teal, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _dataFileHeaders.map((h) {
                    final alreadyAdded =
                        widget.variableFields.any((f) => f.key.trim() == h);
                    return GestureDetector(
                      onTap: alreadyAdded
                          ? null
                          : () {
                              final updated = [
                                ...widget.variableFields,
                                _VarField(key: h)
                              ];
                              widget.onVariableFieldsChanged(updated);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: alreadyAdded
                              ? Colors.teal.withOpacity(0.15)
                              : Colors.teal.withOpacity(0.08),
                          border: Border.all(
                              color: Colors.teal
                                  .withOpacity(alreadyAdded ? 0.5 : 0.3)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!alreadyAdded)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.add_rounded,
                                    size: 12, color: Colors.teal),
                              ),
                            if (alreadyAdded)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_rounded,
                                    size: 12,
                                    color: Colors.teal.withOpacity(0.7)),
                              ),
                            Text(h,
                                style: AppTypography.caption.copyWith(
                                    color: Colors.teal
                                        .withOpacity(alreadyAdded ? 0.6 : 1),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (widget.variableFields.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.teal.withOpacity(0.2),
                  style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(14),
              color: Colors.teal.withOpacity(0.03),
            ),
            child: Column(
              children: [
                Icon(Icons.tune_rounded,
                    color: Colors.teal.withOpacity(0.4), size: 28),
                const SizedBox(height: 6),
                Text('No variable fields yet.',
                    style: AppTypography.bodySmall
                        .copyWith(color: Colors.teal.withOpacity(0.6))),
                const SizedBox(height: 2),
                Text(
                    _dataFileHeaders.isNotEmpty
                        ? 'Tap a column chip above or "Add Field" for a custom field.'
                        : 'Tap "Add Field" to define custom data.',
                    style: AppTypography.caption
                        .copyWith(color: Colors.teal.withOpacity(0.45))),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(
                widget.variableFields.length,
                (i) {
                  final field = widget.variableFields[i];
                  return Container(
                    decoration: BoxDecoration(
                      border: i < widget.variableFields.length - 1
                          ? Border(
                              bottom: BorderSide(
                                  color: Colors.teal.withOpacity(0.12)))
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Field name input
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            initialValue: field.key,
                            onChanged: (v) => _updateVarFieldKey(i, v),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Field name',
                              hintStyle: AppTypography.caption.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.teal.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.teal.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.teal, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.teal.withOpacity(0.04),
                            ),
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Type dropdown
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            value: field.type,
                            isDense: true,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.teal.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.teal.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.teal, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.teal.withOpacity(0.04),
                            ),
                            style: AppTypography.bodySmall,
                            items: const [
                              DropdownMenuItem(
                                  value: 'text', child: Text('Text')),
                              DropdownMenuItem(
                                  value: 'number', child: Text('Number')),
                              DropdownMenuItem(
                                  value: 'image', child: Text('Image')),
                            ],
                            onChanged: (v) {
                              if (v != null) _updateVarFieldType(i, v);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete
                        GestureDetector(
                          onTap: () => _removeVarField(i),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.09),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.red, size: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 28),

        // ────────────────────────────────────────────────────────────
        // 4. UPLOAD DATA FILE (Excel / CSV) — must happen before mapping
        // ────────────────────────────────────────────────────────────
        _sectionHeader(
            'Upload Data File', Icons.upload_file_rounded, Colors.teal),
        const SizedBox(height: 6),
        Text(
          'Upload your Excel or CSV so columns can be mapped to template fields.',
          style: AppTypography.bodySmall
              .copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap:
              (_isPickingDataFile || _parsingDataFile) ? null : _pickDataFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _dataFileHeaders.isNotEmpty
                    ? Colors.teal
                    : _dataFileError != null
                        ? Colors.red.withOpacity(0.6)
                        : Colors.teal.withOpacity(0.35),
                width: _dataFileHeaders.isNotEmpty ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: _dataFileHeaders.isNotEmpty
                  ? Colors.teal.withOpacity(0.05)
                  : _dataFileError != null
                      ? Colors.red.withOpacity(0.04)
                      : Colors.teal.withOpacity(0.03),
            ),
            child: (_isPickingDataFile || _parsingDataFile)
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.teal)),
                    const SizedBox(width: 10),
                    Text(_isPickingDataFile ? 'Selecting…' : 'Reading headers…',
                        style: AppTypography.labelMedium
                            .copyWith(color: Colors.teal)),
                  ])
                : _dataFileHeaders.isNotEmpty
                    ? Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.12),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle_rounded,
                              color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_dataFileName,
                                    style: AppTypography.labelMedium
                                        .copyWith(color: Colors.teal),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                    '${_dataFileHeaders.length} columns detected — tap to change',
                                    style: AppTypography.caption.copyWith(
                                        color: Colors.teal.withOpacity(0.7))),
                              ]),
                        ),
                      ])
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(
                              _dataFileError != null
                                  ? Icons.error_outline_rounded
                                  : Icons.table_chart_rounded,
                              size: 32,
                              color: _dataFileError != null
                                  ? Colors.red.withOpacity(0.7)
                                  : Colors.teal.withOpacity(0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _dataFileError != null
                                  ? 'Tap to try again'
                                  : 'Tap to select Excel / CSV',
                              style: AppTypography.labelMedium.copyWith(
                                  color: _dataFileError != null
                                      ? Colors.red
                                      : Colors.teal),
                            ),
                            if (_dataFileError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 4, left: 12, right: 12),
                                child: Text(_dataFileError!,
                                    style: AppTypography.caption
                                        .copyWith(color: Colors.red),
                                    textAlign: TextAlign.center),
                              )
                            else
                              Text('.xlsx • .xls • .csv',
                                  style: AppTypography.caption.copyWith(
                                      color: Colors.teal.withOpacity(0.45))),
                          ]),
          ),
        ),

        const SizedBox(height: 28),

        // ────────────────────────────────────────────────────────────
        // 5. MAP DATA FIELDS  (gated behind data-file upload)
        // ────────────────────────────────────────────────────────────
        _sectionHeader('Map Data Fields', Icons.grid_on_rounded, Colors.indigo),
        const SizedBox(height: 4),
        Text(
          _dataFileHeaders.isEmpty
              ? 'Upload your data file above — columns will auto-appear here.'
              : '${_dataFileHeaders.length} columns detected from Excel. Reassign any column using the dropdown.',
          style: AppTypography.bodySmall
              .copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
        const SizedBox(height: 12),

        if (_dataFileHeaders.isEmpty)
          // Locked placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.indigo.withOpacity(0.18)),
              borderRadius: BorderRadius.circular(14),
              color: Colors.indigo.withOpacity(0.02),
            ),
            child: Column(children: [
              Icon(Icons.lock_outline_rounded,
                  color: Colors.indigo.withOpacity(0.35), size: 32),
              const SizedBox(height: 8),
              Text('Upload a data file to unlock mapping',
                  style: AppTypography.bodySmall
                      .copyWith(color: Colors.indigo.withOpacity(0.5))),
            ]),
          )
        else
          Builder(builder: (context) {
            final dataFields = _activeFields;
            final dropdownItems = <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'Not mapped',
                child: Text('— skip —',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12)),
              ),
              ..._dataFileHeaders.map((h) => DropdownMenuItem<String>(
                    value: h,
                    child: Text(h,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: theme.colorScheme.onSurface, fontSize: 12)),
                  )),
            ];

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: List.generate(dataFields.length, (i) {
                  final field = dataFields[i];
                  final current = widget.columnMappings[field] ?? 'Not mapped';
                  final isMapped = current != 'Not mapped';

                  // Auto-suggest on first render — only if not already set
                  if (!widget.columnMappings.containsKey(field)) {
                    final lower = field
                        .toLowerCase()
                        .replaceAll(' ', '')
                        .replaceAll('/', '');
                    for (final h in _dataFileHeaders) {
                      final hl = h
                          .toLowerCase()
                          .replaceAll(' ', '')
                          .replaceAll('_', '');
                      if (hl == lower ||
                          hl.contains(lower) ||
                          lower.contains(hl)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            final updated =
                                Map<String, String>.from(widget.columnMappings);
                            updated[field] = h;
                            widget.onColumnMappingsChanged(updated);
                          }
                        });
                        break;
                      }
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: isMapped ? Colors.indigo.withOpacity(0.04) : null,
                      border: i < dataFields.length - 1
                          ? Border(
                              bottom: BorderSide(
                                  color: Colors.indigo.withOpacity(0.1)))
                          : null,
                      borderRadius: i == 0
                          ? const BorderRadius.vertical(
                              top: Radius.circular(14))
                          : i == dataFields.length - 1
                              ? const BorderRadius.vertical(
                                  bottom: Radius.circular(14))
                              : BorderRadius.zero,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field,
                                  style: AppTypography.labelSmall
                                      .copyWith(fontWeight: FontWeight.w600)),
                              if (isMapped)
                                Text('→ $current',
                                    style: AppTypography.caption.copyWith(
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            value: dropdownItems.any((d) => d.value == current)
                                ? current
                                : 'Not mapped',
                            isDense: true,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.indigo.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.indigo.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.indigo, width: 1.5),
                              ),
                              filled: true,
                              fillColor: isMapped
                                  ? Colors.indigo.withOpacity(0.06)
                                  : theme.colorScheme.surface,
                            ),
                            style: AppTypography.bodySmall.copyWith(
                                fontWeight: isMapped
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isMapped
                                    ? Colors.indigo
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.6)),
                            items: dropdownItems,
                            onChanged: (v) {
                              final updated = Map<String, String>.from(
                                  widget.columnMappings);
                              if (v == null || v == 'Not mapped') {
                                updated.remove(field);
                              } else {
                                updated[field] = v;
                              }
                              widget.onColumnMappingsChanged(updated);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            );
          }),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _Step3 extends StatefulWidget {
  final List<_OrderFile> selectedFiles;
  final TextEditingController descriptionCtrl;
  final void Function(List<_OrderFile>) onFilesChanged;
  final List<String> orderImages;
  final void Function(List<String>) onOrderImagesChanged;
  final TextEditingController quantityCtrl;
  final void Function(int qty) onQuantityChanged;
  final int excelRowCount;
  final String unit;
  final void Function(String unit) onUnitChanged;

  const _Step3({
    required this.selectedFiles,
    required this.descriptionCtrl,
    required this.onFilesChanged,
    required this.orderImages,
    required this.onOrderImagesChanged,
    required this.quantityCtrl,
    required this.onQuantityChanged,
    this.excelRowCount = 0,
    this.unit = 'Pieces',
    required this.onUnitChanged,
  });

  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isPickingOrderImages = false;

  // ── Order-image pick helpers ─────────────────────────────────────
  Future<void> _pickOrderImagesFromGallery() async {
    setState(() => _isPickingOrderImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
          imageQuality: 80, maxWidth: 1920, maxHeight: 1920);
      if (picked.isNotEmpty) {
        final updated = [...widget.orderImages, ...picked.map((x) => x.path)];
        widget.onOrderImagesChanged(updated.take(10).toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gallery error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPickingOrderImages = false);
    }
  }

  Future<void> _captureOrderImage() async {
    setState(() => _isPickingOrderImages = true);
    try {
      final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920);
      if (picked != null) {
        final updated = [...widget.orderImages, picked.path];
        widget.onOrderImagesChanged(updated.take(10).toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPickingOrderImages = false);
    }
  }

  void _removeOrderImage(int index) {
    final updated = List<String>.from(widget.orderImages)..removeAt(index);
    widget.onOrderImagesChanged(updated);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Add Order Images',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _captureOrderImage();
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.secondary),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Pick multiple photos'),
              onTap: () {
                Navigator.of(context).pop();
                _pickOrderImagesFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Add Files',
                    style: AppTypography.titleSmall
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.secondary),
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Pick from photos'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_open_rounded,
                      color: Colors.deepOrange),
                ),
                title: const Text('Files'),
                subtitle: const Text('PDF, CDR, AI, JPG, PNG…'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxHeight: 1920,
        maxWidth: 1920,
      );
      if (picked.isNotEmpty) {
        final added = picked
            .map((x) => _OrderFile(path: x.path, name: x.name, isImage: true))
            .toList();
        widget.onFilesChanged([...widget.selectedFiles, ...added]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking from gallery: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() => _isLoading = true);
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxHeight: 1920,
        maxWidth: 1920,
      );
      if (picked != null) {
        widget.onFilesChanged([
          ...widget.selectedFiles,
          _OrderFile(path: picked.path, name: picked.name, isImage: true),
        ]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'cdr',
          'ai',
          'psd',
          'eps',
          'svg',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
        final added = result.files.where((f) => f.path != null).map((f) {
          final ext = f.extension?.toLowerCase() ?? '';
          return _OrderFile(
            path: f.path!,
            name: f.name,
            isImage: imageExts.contains(ext),
          );
        }).toList();
        widget.onFilesChanged([...widget.selectedFiles, ...added]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeFile(int index) {
    final updated = List<_OrderFile>.from(widget.selectedFiles);
    updated.removeAt(index);
    widget.onFilesChanged(updated);
  }

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'cdr':
      case 'ai':
      case 'psd':
      case 'eps':
      case 'svg':
        return Icons.palette_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'cdr':
      case 'ai':
      case 'psd':
      case 'eps':
      case 'svg':
        return Colors.deepOrange;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderImages = widget.orderImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Images & Quantity', style: AppTypography.titleSmall),
        const SizedBox(height: 16),

        // ─── Order Images section ────────────────────────────────────
        Row(
          children: [
            Text('Order Images',
                style: AppTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (orderImages.isNotEmpty && orderImages.length < 10)
              TextButton.icon(
                onPressed: _isPickingOrderImages ? null : _showImageSourceSheet,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Upload photos of the order — visible in Order Details.',
          style: AppTypography.bodySmall.copyWith(color: Colors.grey.shade500),
        ),
        const SizedBox(height: 10),

        if (orderImages.isEmpty)
          GestureDetector(
            onTap: _isPickingOrderImages ? null : _showImageSourceSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              height: 130,
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3), width: 1.5),
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primary.withOpacity(0.04),
              ),
              child: _isPickingOrderImages
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            size: 36,
                            color: AppColors.primary.withOpacity(0.5)),
                        const SizedBox(height: 8),
                        Text('Tap to add order images',
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.primary)),
                        Text('Camera or Gallery • max 10',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.primary.withOpacity(0.5))),
                      ],
                    ),
            ),
          )
        else ...[
          if (_isPickingOrderImages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(),
            ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: orderImages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                if (i == orderImages.length) {
                  // "Add more" tile
                  if (orderImages.length >= 10) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: _isPickingOrderImages ? null : _showImageSourceSheet,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5),
                        color: AppColors.primary.withOpacity(0.04),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.primary.withOpacity(0.5),
                              size: 22),
                          const SizedBox(height: 4),
                          Text('Add',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  );
                }
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(orderImages[i]),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_rounded,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: GestureDetector(
                      onTap: () => _removeOrderImage(i),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${orderImages.length}/10 image${orderImages.length == 1 ? '' : 's'} selected',
              style: AppTypography.caption.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        // ─── Quantity section ─────────────────────────────────────────
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Quantity',
                style: AppTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            if (widget.excelRowCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_chart_rounded,
                        size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                        'Auto-filled from Excel (${widget.excelRowCount} rows)',
                        style: AppTypography.caption.copyWith(
                            color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.quantityCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: 'Number of items',
            prefixIcon: Icon(Icons.tag_rounded,
                color: AppColors.primary.withOpacity(0.7)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.primary.withOpacity(0.04),
          ),
          style: AppTypography.bodyMedium,
          onChanged: (val) {
            final q = int.tryParse(val.trim());
            if (q != null && q > 0) widget.onQuantityChanged(q);
          },
        ),

        // ─── Units section ────────────────────────────────────────────
        const SizedBox(height: 16),
        Text('Unit',
            style: AppTypography.labelMedium
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.unit,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Unit',
            prefixIcon: Icon(Icons.straighten_rounded,
                color: AppColors.primary.withOpacity(0.7)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.primary.withOpacity(0.04),
          ),
          items: const [
            'Pieces',
            'Sets',
            'Pens',
            'Cards',
            'Sheets',
            'Copies',
            'Badges',
            'Books',
            'Boxes',
            'Rolls',
            'Packets',
            'Other',
          ].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (val) {
            if (val != null) widget.onUnitChanged(val);
          },
        ),
      ],
    );
  }
}

/// Small icon+label chip shown in the empty upload area.
class _SourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SourceChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Lightweight model representing a file chosen by the user (image or document).
class _OrderFile {
  final String path;
  final String name;

  /// true = display as image thumbnail; false = display as file card
  final bool isImage;

  const _OrderFile(
      {required this.path, required this.name, required this.isImage});
}

class _Step4 extends StatelessWidget {
  final String title;
  final String school;
  final String product;
  final String deliveryDate;
  final int quantity;
  final String unit;
  final String description;
  final int fileCount;
  final int imageCount;
  final String csvFileName;
  const _Step4({
    required this.title,
    required this.school,
    required this.product,
    required this.deliveryDate,
    this.quantity = 1,
    this.unit = 'Pieces',
    this.description = '',
    this.fileCount = 0,
    this.imageCount = 0,
    this.csvFileName = '',
  });

  @override
  Widget build(BuildContext context) {
    final displayFields = <Map<String, String>>[
      {'label': 'Order Title', 'value': title},
      {'label': 'Client', 'value': school},
      {'label': 'Product', 'value': product},
      {'label': 'Delivery', 'value': deliveryDate},
      {'label': 'Quantity', 'value': '$quantity $unit'},
      {'label': 'Unit', 'value': unit},
      if (description.isNotEmpty)
        {'label': 'Description', 'value': description},
      if (csvFileName.isNotEmpty) {'label': 'Data File', 'value': csvFileName},
      if (fileCount > 0)
        {
          'label': 'Attachments',
          'value': '$fileCount file${fileCount == 1 ? '' : 's'}'
        },
      if (imageCount > 0)
        {
          'label': 'Images',
          'value': '$imageCount image${imageCount == 1 ? '' : 's'}'
        },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Submit', style: AppTypography.titleSmall),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: displayFields
                .map((f) => _ReviewRow(f['label']!, f['value']!))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTypography.labelMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// UPLOAD EXCEL
// -------------------------------------------------------------------
class UploadExcelScreen extends StatefulWidget {
  const UploadExcelScreen({super.key});

  @override
  State<UploadExcelScreen> createState() => _UploadExcelScreenState();
}

class _UploadExcelScreenState extends State<UploadExcelScreen> {
  bool _fileSelected = false;
  bool _parsing = false;
  String _fileName = '';
  String? _filePath;
  List<int>? _fileBytes;
  List<String> _parsedHeaders = [];
  List<List<String>> _previewRows = []; // up to 5 data rows for preview
  String? _parseError;

  // Step tracker: 0=upload, 1=preview+proceed
  int _step = 0;

  // Client selection
  String? _selectedClientId;
  String? _selectedClientName;
  List<Map<String, String>> _clients = [];
  bool _loadingClients = true;
  String? _clientLoadError;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      setState(() {
        _loadingClients = true;
        _clientLoadError = null;
      });
      final res = await _dio().get('$_kServerBase/api/clients');
      if (res.statusCode == 200 && res.data is List) {
        final list = (res.data as List)
            .map((c) => {
                  'id': (c['_id'] ?? c['id'] ?? '').toString(),
                  'name': (c['name'] ?? 'Unknown').toString(),
                })
            .where((c) => c['id']!.isNotEmpty)
            .toList();
        if (mounted)
          setState(() {
            _clients = list;
            _loadingClients = false;
          });
      } else {
        if (mounted) setState(() => _loadingClients = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingClients = false;
          _clientLoadError = 'Failed to load clients';
        });
      }
    }
  }

  Future<void> _pickFile() async {
    debugPrint('[ExcelUpload] STEP 1: PICK START');
    FilePickerResult? result;
    try {
      // FIX 1: Use FileType.any — avoids MIME-type mismatch on Vivo/OPPO/Xiaomi
      //        file managers that silently reject FileType.custom selections.
      // FIX 2: withData: false — do NOT read bytes inside the picker call;
      //        reading happens on the main thread and causes ANR-like freezes.
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
    } catch (e) {
      debugPrint('[ExcelUpload] FilePicker threw: $e');
      if (mounted)
        setState(() => _parseError = 'Could not open file picker: $e');
      return;
    }

    if (result == null || result.files.isEmpty) {
      debugPrint('[ExcelUpload] user cancelled / no file returned');
      return;
    }

    final file = result.files.first;
    debugPrint('[ExcelUpload] STEP 2: FILE SELECTED: ${file.name}');
    debugPrint('[ExcelUpload] FILE PATH: ${file.path}');

    // Validate extension in Dart (replaces MIME filtering)
    final ext = file.name.split('.').last.toLowerCase();
    if (!['xlsx', 'xls', 'csv'].contains(ext)) {
      debugPrint('[ExcelUpload] rejected extension: $ext');
      if (mounted) {
        setState(() => _parseError =
            'Unsupported file type ".$ext". Please select .xlsx, .xls or .csv');
      }
      return;
    }

    if (file.path == null) {
      debugPrint('[ExcelUpload] path is null — cannot read file');
      if (mounted)
        setState(() =>
            _parseError = 'Could not access file path. Please try again.');
      return;
    }

    setState(() {
      _parsing = true;
      _parseError = null;
      _fileSelected = false;
      _parsedHeaders = [];
    });

    try {
      // compute() takes a DIRECT function reference — no closure, no 'this' capture.
      // This is the only safe way to run background work in Flutter.
      debugPrint('[ExcelUpload] STEP 3: COMPUTE START');
      debugPrint('[ExcelUpload] FILE PATH: ${file.path}');
      final headers = await compute(parseHeadersCompute, file.path!);
      debugPrint('[ExcelUpload] STEP 4: HEADERS: $headers');
      final preview = await compute(parsePreviewCompute, file.path!);
      debugPrint('[ExcelUpload] PREVIEW ROWS: ${preview.length}');

      if (!mounted) return;
      setState(() {
        _fileSelected = true;
        _fileName = file.name;
        _filePath = file.path;
        _fileBytes = null;
        _parsedHeaders = headers;
        _previewRows = preview;
        _parsing = false;
        _step = 1;
      });
    } catch (e, stack) {
      debugPrint('[ExcelUpload] PARSE ERROR: $e');
      debugPrint('[ExcelUpload] STACK: $stack');
      if (mounted) {
        setState(() {
          _parsing = false;
          _parseError = 'Could not read file headers: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read Excel file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  bool _saving = false;

  /// Auto-maps parsed headers to system field keys and sends the file to the
  /// backend for ingestion — no manual column-mapping step required.
  Future<void> _saveData() async {
    if (_filePath == null) return;

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a client before saving.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Build auto-mapping: field key → best-matching header name
    Map<String, String> _autoMap(List<String> headers) {
      String? match(String fieldLabel) {
        final lower =
            fieldLabel.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
        for (final h in headers) {
          final hl = h.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
          if (hl == lower || hl.contains(lower) || lower.contains(hl)) return h;
        }
        return null;
      }

      final raw = <String, String?>{
        'firstName':
            match('First Name') ?? match('firstName') ?? match('fname'),
        'lastName': match('Last Name') ??
            match('lastName') ??
            match('lname') ??
            match('surname'),
        'studentName':
            match('Student Name') ?? match('studentName') ?? match('name'),
        'className': match('Class') ??
            match('className') ??
            match('class') ??
            match('grade') ??
            match('std'),
        'section': match('Section') ?? match('section') ?? match('sec'),
        'rollNumber': match('Roll Number') ??
            match('rollNumber') ??
            match('rollNo') ??
            match('admNo') ??
            match('adm') ??
            match('sr') ??
            match('reg'),
        'dob': match('Date of Birth') ?? match('dob') ?? match('birth'),
        'parentName': match('Parent Name') ??
            match('parentName') ??
            match('parent') ??
            match('father') ??
            match('fatherName'),
        'phone': match('Phone') ??
            match('phone') ??
            match('mobile') ??
            match('fatherMob') ??
            match('mob') ??
            match('contact'),
        'address': match('Address') ?? match('address') ?? match('addr'),
        'teacherName': match('Teacher') ??
            match('teacherName') ??
            match('classTeacher') ??
            match('teacher'),
      };

      // Strip null entries — backend skips null values but cleaner not to send them
      return Map.fromEntries(
        raw.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
    }

    final mapping = _autoMap(_parsedHeaders);

    setState(() => _saving = true);
    try {
      debugPrint('[SaveData] headers: $_parsedHeaders');
      debugPrint(
          '[SaveData] mapping (${mapping.length} fields): ${jsonEncode(mapping)}');

      final formData = FormData();
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(_filePath!, filename: _fileName),
      ));
      formData.fields.add(MapEntry('mapping', jsonEncode(mapping)));
      final vendorId = await _currentVendorId();
      formData.fields.add(MapEntry('vendorId', vendorId));
      formData.fields.add(MapEntry('clientId', _selectedClientId!));

      final response = await _dio().post(
        '$_kServerBase/api/vendor/upload-excel',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      debugPrint('[SaveData] response: ${response.data}');

      if (!mounted) return;
      final data = response.data as Map<String, dynamic>? ?? {};
      final classesCreated = data['classesCreated'] ?? 0;
      final studentsAdded = data['studentsAdded'] ?? 0;
      final teachersAdded = data['teachersAdded'] ?? 0;
      final totalRows = data['totalRows'] ?? 0;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Data Saved!', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$totalRows rows processed from $_fileName',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              _IngestStat(Icons.class_rounded,
                  '$classesCreated classes created', AppColors.primary),
              const SizedBox(height: 8),
              _IngestStat(Icons.person_rounded, '$studentsAdded students added',
                  Colors.teal),
              const SizedBox(height: 8),
              _IngestStat(Icons.school_rounded, '$teachersAdded teachers added',
                  Colors.orange),
              if (_selectedClientName != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_selectedClientName!,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (_selectedClientId != null &&
                      _selectedClientId!.isNotEmpty) {
                    debugPrint(
                        '[SaveData] Navigating to client: $_selectedClientName ($_selectedClientId)');
                    context.go('/vendor/clients/$_selectedClientId');
                  } else {
                    context.go('/vendor/clients');
                  }
                },
                child: const Text('View School Data'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Extract meaningful error message from backend 4xx responses
      String errorMsg = 'Save failed';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) {
          errorMsg = (body['error'] ?? body['message'] ?? errorMsg).toString();
        }
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Upload Failed', style: TextStyle(fontSize: 18))),
          ]),
          content: Text(errorMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Excel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Client Selection ────────────────────────────────────
            Text(
              'Select Client',
              style: AppTypography.labelMedium
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            if (_loadingClients)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withOpacity(0.04),
                ),
                child: Row(children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text('Loading clients…',
                      style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6))),
                ]),
              )
            else if (_clientLoadError != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withOpacity(0.04),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.withOpacity(0.7), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_clientLoadError!,
                            style: AppTypography.bodySmall
                                .copyWith(color: Colors.red))),
                    TextButton(
                        onPressed: _fetchClients, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_clients.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withOpacity(0.04),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.primary.withOpacity(0.7)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('No clients found. Create one first.',
                        style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6))),
                  ),
                ]),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedClientId,
                decoration: InputDecoration(
                  labelText: 'School / Client',
                  hintText: 'Select a client',
                  prefixIcon: Icon(Icons.business_rounded,
                      color: AppColors.primary.withOpacity(0.7)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.primary.withOpacity(0.04),
                ),
                dropdownColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                items: _clients
                    .map((c) => DropdownMenuItem<String>(
                          value: c['id'],
                          child: Text(c['name']!,
                              style: AppTypography.bodyMedium.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    final c = _clients.firstWhere((c) => c['id'] == id);
                    setState(() {
                      _selectedClientId = id;
                      _selectedClientName = c['name'];
                    });
                  }
                },
              ),
            const SizedBox(height: 20),

            // ── Step 1: Drop zone ──────────────────────────────────
            GestureDetector(
              onTap: _parsing ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _fileSelected
                        ? AppColors.success
                        : _parseError != null
                            ? Colors.red
                            : AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: _fileSelected
                      ? AppColors.success.withOpacity(0.05)
                      : _parseError != null
                          ? Colors.red.withOpacity(0.05)
                          : AppColors.primary.withOpacity(0.04),
                ),
                child: _parsing
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Reading file headers…'),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _fileSelected
                                ? Icons.check_circle_rounded
                                : _parseError != null
                                    ? Icons.error_outline_rounded
                                    : Icons.upload_file_rounded,
                            size: 48,
                            color: _fileSelected
                                ? AppColors.success
                                : _parseError != null
                                    ? Colors.red
                                    : AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _fileSelected
                                ? _fileName
                                : _parseError != null
                                    ? 'Tap to try again'
                                    : 'Tap to select Excel / CSV file',
                            style: AppTypography.labelMedium.copyWith(
                              color: _fileSelected
                                  ? AppColors.success
                                  : _parseError != null
                                      ? Colors.red
                                      : AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_fileSelected)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${_parsedHeaders.length} columns detected',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.success.withOpacity(0.8),
                                ),
                              ),
                            ),
                          if (_parseError != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              child: Text(
                                _parseError!,
                                style: AppTypography.caption
                                    .copyWith(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            // ── Step 2: Preview & proceed ──────────────────────────
            if (_step == 1 && _fileSelected) ...[
              const SizedBox(height: 20),
              // ── Data Table (full data, vertical + horizontal scroll) ──
              Text(
                'Data Preview (${_previewRows.length} rows)',
                style: AppTypography.titleSmall
                    .copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 10),
              if (_parsedHeaders.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.18)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                              AppColors.primary.withOpacity(0.12)),
                          columnSpacing: 20,
                          headingTextStyle: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                          dataTextStyle: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurface),
                          columns: _parsedHeaders
                              .map((h) => DataColumn(
                                    label: Text(h,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          rows: _previewRows
                              .map((row) => DataRow(
                                    cells: List.generate(
                                      _parsedHeaders.length,
                                      (i) => DataCell(Text(
                                        i < row.length && row[i].isNotEmpty
                                            ? row[i]
                                            : '—',
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // Navigate to column mapping screen
              GradientButton(
                label: 'Map Columns →',
                loading: false,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ColumnMappingScreen(
                      excelHeaders: _parsedHeaders,
                      fileName: _fileName,
                      filePath: _filePath,
                      fileBytes: _fileBytes,
                      clientId: _selectedClientId,
                      clientName: _selectedClientName,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// TOP-LEVEL function for compute() — direct reference, zero closure capture.
// Takes a single filePath String; derives type from extension.
// -------------------------------------------------------------------
List<String> parseHeadersCompute(String filePath) {
  print('[ExcelUpload] COMPUTE RUNNING, path: $filePath');
  final file = File(filePath);
  if (!file.existsSync()) throw Exception('File not found: $filePath');

  final lower = filePath.toLowerCase();
  if (lower.endsWith('.csv')) {
    final content = file.readAsStringSync();
    final firstLine = content.split('\n').first.trim();
    final headers = firstLine
        .split(',')
        .map((h) => h.trim().replaceAll('"', ''))
        .where((h) => h.isNotEmpty)
        .toList();
    if (headers.isEmpty) throw Exception('No headers found in CSV');
    print('[ExcelUpload] COMPUTE DONE: $headers');
    return headers;
  } else {
    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) throw Exception('File is empty');
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) throw Exception('No sheets found in file');
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) throw Exception('Sheet is empty');
    final headers = rows.first
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .where((h) => h.isNotEmpty)
        .toList();
    if (headers.isEmpty) throw Exception('First row has no column headers');
    print('[ExcelUpload] COMPUTE DONE: $headers');
    return headers;
  }
}

// Returns ALL data rows (excluding header row) for the full-data table.
List<List<String>> parsePreviewCompute(String filePath) {
  print('[ExcelUpload] PREVIEW COMPUTE START, path: $filePath');
  final file = File(filePath);
  if (!file.existsSync()) return [];

  final lower = filePath.toLowerCase();
  if (lower.endsWith('.csv')) {
    final lines = file
        .readAsStringSync()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // skip header row (index 0), return all data rows
    return lines
        .skip(1)
        .map((l) =>
            l.split(',').map((c) => c.trim().replaceAll('"', '')).toList())
        .toList();
  } else {
    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) return [];
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final rows = excel.tables.values.first.rows;
    if (rows.length <= 1) return [];
    return rows
        .skip(1)
        .map((row) =>
            row.map((cell) => cell?.value?.toString().trim() ?? '').toList())
        .toList();
  }
}

// -------------------------------------------------------------------
// COLUMN MAPPING
// -------------------------------------------------------------------

/// Required fields that must be mapped before submission.
const _kRequiredFields = [
  _MappingField('studentName', 'Student Name', Icons.person_rounded),
  _MappingField('className', 'Class', Icons.class_rounded),
  _MappingField('section', 'Section', Icons.bookmark_rounded),
  _MappingField('rollNumber', 'Roll Number', Icons.numbers_rounded),
  _MappingField('dob', 'Date of Birth', Icons.cake_rounded),
  _MappingField('parentName', 'Parent Name', Icons.family_restroom_rounded),
  _MappingField('phone', 'Phone', Icons.phone_rounded),
];

/// Optional fields — shown below required, no validation.
const _kOptionalFields = [
  _MappingField('address', 'Address', Icons.home_rounded),
  _MappingField('photo', 'Photo Filename', Icons.photo_rounded),
];

class _MappingField {
  final String key;
  final String label;
  final IconData icon;
  const _MappingField(this.key, this.label, this.icon);
}

class ColumnMappingScreen extends StatefulWidget {
  final List<String> excelHeaders;
  final String fileName;
  final String? filePath;
  final List<int>? fileBytes;
  final String? clientId;
  final String? clientName;

  const ColumnMappingScreen({
    super.key,
    required this.excelHeaders,
    required this.fileName,
    this.filePath,
    this.fileBytes,
    this.clientId,
    this.clientName,
  });

  @override
  State<ColumnMappingScreen> createState() => _ColumnMappingScreenState();
}

class _ColumnMappingScreenState extends State<ColumnMappingScreen> {
  static const _kBaseUrl = _kServerBase;

  /// key → selected excel column name
  final Map<String, String?> _mapping = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-suggest: try to match by case-insensitive similarity
    for (final field in [..._kRequiredFields, ..._kOptionalFields]) {
      _mapping[field.key] = _autoMatch(field.label);
    }
  }

  String? _autoMatch(String fieldLabel) {
    final lower = fieldLabel.toLowerCase().replaceAll(' ', '');
    for (final h in widget.excelHeaders) {
      final hl = h.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
      if (hl == lower || hl.contains(lower) || lower.contains(hl)) {
        return h;
      }
    }
    return null;
  }

  String? _validate() {
    for (final f in _kRequiredFields) {
      if (_mapping[f.key] == null) {
        return 'Please map: ${f.label}';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final formData = FormData();

      // Attach file if available
      if (widget.filePath != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(
            widget.filePath!,
            filename: widget.fileName,
          ),
        ));
      } else if (widget.fileBytes != null) {
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            widget.fileBytes!,
            filename: widget.fileName,
          ),
        ));
      }

      // Attach mapping as JSON
      formData.fields.add(MapEntry('mapping', jsonEncode(_mapping)));

      final vendorId = await _currentVendorId();
      formData.fields.add(MapEntry('vendorId', vendorId));
      if (widget.clientId != null && widget.clientId!.isNotEmpty) {
        formData.fields.add(MapEntry('clientId', widget.clientId!));
      }

      final response = await _dio().post(
        '$_kBaseUrl/api/vendor/upload-excel',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>? ?? {};
      final classesCreated = data['classesCreated'] ?? 0;
      final studentsAdded = data['studentsAdded'] ?? 0;
      final teachersAdded = data['teachersAdded'] ?? 0;
      final totalRows = data['totalRows'] ?? 0;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child:
                      Text('Data Ingested!', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$totalRows rows processed from ${widget.fileName}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              _IngestStat(Icons.class_rounded,
                  '$classesCreated classes created', AppColors.primary),
              const SizedBox(height: 8),
              _IngestStat(Icons.person_rounded, '$studentsAdded students added',
                  Colors.teal),
              const SizedBox(height: 8),
              _IngestStat(Icons.school_rounded, '$teachersAdded teachers added',
                  Colors.orange),
              if (widget.clientName != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(widget.clientName!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (widget.clientId != null && widget.clientId!.isNotEmpty) {
                    debugPrint(
                        '[ColumnMapping] Navigating to client: ${widget.clientName} (${widget.clientId})');
                    context.go('/vendor/clients/${widget.clientId}');
                  } else {
                    context.go('/vendor/clients');
                  }
                },
                child: const Text('View School Data'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = widget.excelHeaders;
    // null option = "-- not mapped --"
    final dropdownItems = [
      DropdownMenuItem<String>(
        value: null,
        child: Text('— skip —',
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                fontSize: 12)),
      ),
      ...headers.map((h) => DropdownMenuItem<String>(
            value: h,
            child: Text(h,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12)),
          )),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Columns'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.fileName,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Required fields ──────────────────────────────
                _SectionLabel(
                  label: 'Required Fields',
                  subtitle: 'All must be mapped',
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 8),
                ..._kRequiredFields.map((f) => _MappingRow(
                      field: f,
                      dropdownItems: dropdownItems,
                      value: _mapping[f.key],
                      required: true,
                      onChanged: (v) => setState(() => _mapping[f.key] = v),
                    )),

                const SizedBox(height: 20),

                // ── Optional fields ──────────────────────────────
                _SectionLabel(
                  label: 'Optional Fields',
                  subtitle: 'Map if available',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                ..._kOptionalFields.map((f) => _MappingRow(
                      field: f,
                      dropdownItems: dropdownItems,
                      value: _mapping[f.key],
                      required: false,
                      onChanged: (v) => setState(() => _mapping[f.key] = v),
                    )),

                const SizedBox(height: 80), // space above FAB
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GradientButton(
              label: 'Confirm & Upload Data',
              loading: _submitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small stat row shown inside the post-upload success dialog.
class _IngestStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _IngestStat(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  const _SectionLabel(
      {required this.label, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.labelMedium.copyWith(color: color)),
            Text(subtitle,
                style: AppTypography.caption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55))),
          ],
        ),
      ],
    );
  }
}

class _MappingRow extends StatelessWidget {
  final _MappingField field;
  final List<DropdownMenuItem<String?>> dropdownItems;
  final String? value;
  final bool required;
  final ValueChanged<String?> onChanged;

  const _MappingRow({
    required this.field,
    required this.dropdownItems,
    required this.value,
    required this.required,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMapped = value != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMapped
            ? AppColors.primary.withOpacity(0.08)
            : required
                ? Colors.red.withOpacity(0.06)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMapped
              ? AppColors.primary.withOpacity(0.3)
              : required
                  ? Colors.red.withOpacity(0.3)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Left: required field label
          Expanded(
            child: Row(
              children: [
                Icon(field.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.label,
                          style: AppTypography.labelMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis),
                      if (required)
                        Text('required',
                            style: AppTypography.caption.copyWith(
                                color: Colors.red.shade400, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Icon(Icons.arrow_forward_rounded,
              size: 16, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(width: 8),

          // Right: dropdown
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: value,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.primary.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.primary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              dropdownColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              hint: Text('Select column',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45))),
              items: dropdownItems,
              onChanged: onChanged,
              style: AppTypography.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),

          // Status icon
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              isMapped
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isMapped ? AppColors.success : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// UPLOAD PHOTOS
// -------------------------------------------------------------------

// ── School entry model for upload-photos school selector ────────────
class _UploadSchoolEntry {
  final String id;
  final String name;
  final String code;
  const _UploadSchoolEntry(
      {required this.id, required this.name, required this.code});
}

// ── Select School bottom sheet for Upload Photos ─────────────────────
class _UploadSelectSchoolSheet extends StatefulWidget {
  const _UploadSelectSchoolSheet();

  @override
  State<_UploadSelectSchoolSheet> createState() =>
      _UploadSelectSchoolSheetState();
}

class _UploadSelectSchoolSheetState extends State<_UploadSelectSchoolSheet> {
  final _searchCtrl = TextEditingController();
  List<_UploadSchoolEntry> _all = [];
  List<_UploadSchoolEntry> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final resp = await dio.get('/api/schools');
      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List)
            .map((e) => _UploadSchoolEntry(
                  id: e['id'].toString(),
                  name: e['name'].toString(),
                  code: e['code'].toString(),
                ))
            .toList();
        if (mounted) {
          setState(() {
            _all = list;
            _filtered = list;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load schools.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to server.';
          _loading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  s.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded,
                        color: AppColors.secondary, size: 22),
                    const SizedBox(width: 10),
                    Text('Select School',
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search school name or code\u2026',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: _onSearch,
                ),
              ),
              // List content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 40),
                                const SizedBox(height: 12),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodyMedium),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                  onPressed: _fetchSchools,
                                ),
                              ],
                            ),
                          )
                        : _filtered.isEmpty
                            ? Center(
                                child: Text(
                                  _searchCtrl.text.isEmpty
                                      ? 'No schools found.'
                                      : 'No match for "${_searchCtrl.text}"',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.only(
                                    left: 12, right: 12, bottom: 24),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final s = _filtered[i];
                                  return ListTile(
                                    leading: const Icon(Icons.school),
                                    title: Text(s.name,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w600)),
                                    subtitle: s.code.isNotEmpty
                                        ? Text('Code: ${s.code}',
                                            style: AppTypography.caption)
                                        : null,
                                    onTap: () => Navigator.of(context).pop(s),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UploadPhotosScreen extends StatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  State<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends State<UploadPhotosScreen> {
  // ── Upload state ─────────────────────────────────────────────────
  bool _uploading = false;
  double _progress = 0;
  int _done = 0;
  int _total = 0;
  final List<Map<String, String>> _uploadedFiles = [];

  // ── School selector state ─────────────────────────────────────────
  List<_UploadSchoolEntry> _schools = [];
  _UploadSchoolEntry? _selectedSchool;
  bool _schoolsLoading = true;
  String? _schoolsError;
  final TextEditingController _classNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  @override
  void dispose() {
    _classNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _schoolsLoading = true;
      _schoolsError = null;
    });
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final resp = await dio.get('/api/schools');
      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List)
            .map((e) => _UploadSchoolEntry(
                  id: e['id'].toString(),
                  name: e['name'].toString(),
                  code: e['code'].toString(),
                ))
            .toList();
        if (mounted) {
          setState(() {
            _schools = list;
            _schoolsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _schoolsError = 'Failed to load schools.';
            _schoolsLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _schoolsError = 'Could not connect to server.';
          _schoolsLoading = false;
        });
      }
    }
  }

  Future<String> _getVendorUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUserData);
      if (raw == null) return 'vendor';
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['name'] ?? map['username'] ?? 'vendor').toString();
    } catch (_) {
      return 'vendor';
    }
  }

  Future<void> _pickAndUpload() async {
    if (_selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a school first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    setState(() {
      _uploading = true;
      _progress = 0;
      _done = 0;
      _total = files.length;
      _uploadedFiles.clear();
    });

    final token = await AuthService.instance.getStoredToken();
    final username = await _getVendorUsername();
    final schoolCode = _selectedSchool!.code.isNotEmpty
        ? _selectedSchool!.code
        : _selectedSchool!.id;
    final className = _classNameCtrl.text.trim();

    // Ensure class exists (or create) before uploading
    if (className.isNotEmpty) {
      try {
        await ClassService.checkOrCreateClass(
            schoolId: _selectedSchool!.id, className: className);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not verify/create class'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      // Derive admission number from filename (strip extension)
      final nameNoExt = f.name.contains('.')
          ? f.name.substring(0, f.name.lastIndexOf('.'))
          : f.name;
      final admno = nameNoExt.replaceAll(RegExp(r'[^\w]'), '_');
      try {
        // IMPORTANT: text fields MUST come before the file field so that
        // multer's diskStorage destination/filename callbacks can read
        // req.body.schoolCode / className when the file part streams in.
        final formData = FormData.fromMap({
          'schoolCode': schoolCode,
          'admno': admno,
          'className': className,
          'username': username,
          'image': await MultipartFile.fromFile(f.path!, filename: f.name),
        });
        final resp = await _dioWithAuth(token).post(
          '${ApiConfig.baseUrl}/api/upload/school-photo',
          data: formData,
        );
        final url = (resp.data['url'] ?? '').toString();
        if (url.isNotEmpty) {
          _uploadedFiles.add({'name': f.name, 'url': url});
        }
      } catch (e) {
        debugPrint('[UploadPhotos] failed to upload ${f.name}: $e');
      }
      if (mounted) {
        setState(() {
          _done = i + 1;
          _progress = _done / _total;
        });
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Photos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. SELECT SCHOOL SECTION ─────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Select School',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_schoolsLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  ))
                else if (_schoolsError != null)
                  Row(
                    children: [
                      Text(_schoolsError!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(width: 8),
                      TextButton(
                          onPressed: _loadSchools, child: const Text('Retry')),
                    ],
                  )
                else
                  DropdownButtonFormField<_UploadSchoolEntry>(
                    value: _selectedSchool,
                    hint: const Text('Select School'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon:
                          Icon(Icons.school, color: AppColors.secondary),
                    ),
                    items: _schools
                        .map((school) => DropdownMenuItem(
                              value: school,
                              child: Text(
                                school.code.isNotEmpty
                                    ? '${school.name} (${school.code})'
                                    : school.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSchool = value),
                  ),
                const SizedBox(height: 12),
                // Optional class name
                TextField(
                  controller: _classNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Class Name (optional)',
                    hintText: 'e.g. 10A',
                    prefixIcon: const Icon(Icons.class_),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Divider(height: 28),
              ],
            ),

            // ── 2. PHOTO REQUIREMENTS ────────────────────────────
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Photo Requirements',
                          style: AppTypography.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...const [
                    'Format: JPG or PNG',
                    'Min. 200\u00d7200px',
                    'Clear face, no sunglasses',
                    'Filename = Roll Number / Adm No',
                  ].map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 14),
                            SizedBox(width: 8),
                            Text(r, style: AppTypography.bodySmall),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 3. UPLOAD ZONE ───────────────────────────────────
            GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedSchool != null
                        ? AppColors.secondary.withOpacity(0.5)
                        : AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: _selectedSchool != null
                      ? AppColors.secondary.withOpacity(0.04)
                      : AppColors.primary.withOpacity(0.04),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_rounded,
                      size: 48,
                      color: _selectedSchool != null
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    Text('Select Photo Folder',
                        style: AppTypography.labelMedium),
                    Text(
                      _selectedSchool != null
                          ? 'Upload photos for ${_selectedSchool!.name}'
                          : 'Select a school above first',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_uploading || _progress > 0) ...[
              const SizedBox(height: 20),
              Text(
                _uploading
                    ? 'Uploading photos ($_done / $_total)…'
                    : 'Uploaded $_done / $_total photos',
                style: AppTypography.labelMedium.copyWith(
                  color: _uploading ? AppColors.primary : AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                color: _uploading ? AppColors.primary : AppColors.success,
                backgroundColor: AppColors.primary.withOpacity(0.1),
              ),
            ],
            if (!_uploading && _uploadedFiles.isNotEmpty) ...[
              const SizedBox(height: 24),
              GradientButton(
                label: 'Match Photos to Students',
                onPressed: () => context.go('/vendor/bulk-photo-matching'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// BULK PHOTO MATCHING
// -------------------------------------------------------------------
class BulkPhotoMatchingScreen extends StatelessWidget {
  const BulkPhotoMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Matching'),
        actions: [
          TextButton(
            onPressed: () => context.go('/vendor/project-board'),
            child: const Text('Done'),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No photos uploaded yet.\nUpload student photos to begin matching.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// ORDERS RECEIVED
// -------------------------------------------------------------------
class ProjectBoardScreen extends StatefulWidget {
  const ProjectBoardScreen({super.key});

  @override
  State<ProjectBoardScreen> createState() => _ProjectBoardScreenState();
}

class _ProjectBoardScreenState extends State<ProjectBoardScreen> {
  static const _kBaseUrl = _kServerBase;

  static const _stages = [
    'Draft',
    'Data Upload',
    'Design',
    'Proof',
    'Printing',
    'Dispatch',
    'Delivered',
  ];
  static const _stageColors = [
    AppColors.roleDataOperator,
    AppColors.primary,
    AppColors.roleDesigner,
    AppColors.accent,
    AppColors.secondary,
    AppColors.roleSalesPerson,
    AppColors.success,
  ];

  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _orders = {};

  // ── Search & sort state ─────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _query = '';
  // null = original order | true = date ascending | false = date descending
  bool? _sortAscending;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text;
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final vendorId = await _currentVendorId();
      final response = await _dio().get(
        '$_kBaseUrl/api/vendor/orders',
        queryParameters: {'vendorId': vendorId},
      );
      final data = response.data as Map<String, dynamic>;
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final stage in [..._stages, 'Delivered']) {
        grouped[stage] =
            (data[stage] as List? ?? []).cast<Map<String, dynamic>>();
      }
      if (!mounted) return;
      setState(() {
        _orders = grouped;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[ProjectBoard] load error: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load orders: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Filter a stage bucket by the current query ───────────────────
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list) {
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where((o) =>
            (o['title'] as String? ?? '').toLowerCase().contains(q) ||
            (o['schoolName'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  // ── Sort a list by deliveryDate ─────────────────────────────────
  List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> list) {
    if (_sortAscending == null) return list;
    final asc = _sortAscending!;
    final sorted = [...list];
    sorted.sort((a, b) {
      final da = _parseDate(a['deliveryDate']);
      final db = _parseDate(b['deliveryDate']);
      if (da == null && db == null) return 0;
      if (da == null) return 1; // nulls last
      if (db == null) return -1;
      return asc ? da.compareTo(db) : db.compareTo(da);
    });
    return sorted;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _process(List<Map<String, dynamic>> list) =>
      _sort(_filter(list));

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Sort Orders',
                style: AppTypography.labelLarge
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _SortTile(
              icon: Icons.arrow_upward_rounded,
              label: 'Due Date — Nearest first',
              selected: _sortAscending == true,
              onTap: () {
                setState(() => _sortAscending = true);
                Navigator.pop(context);
              },
            ),
            _SortTile(
              icon: Icons.arrow_downward_rounded,
              label: 'Due Date — Latest first',
              selected: _sortAscending == false,
              onTap: () {
                setState(() => _sortAscending = false);
                Navigator.pop(context);
              },
            ),
            _SortTile(
              icon: Icons.format_list_numbered_rounded,
              label: 'Default order',
              selected: _sortAscending == null,
              onTap: () {
                setState(() => _sortAscending = null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Orders Received')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final completedOrders = _process(_orders['Delivered'] ?? []);

    // Total visible order count across active stages (for search feedback)
    final visibleCount = _stages
        .map((s) => _process(_orders[s] ?? []).length)
        .fold(0, (sum, n) => sum + n);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Received'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.sort_rounded,
              color: _sortAscending != null ? AppColors.secondary : null,
            ),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        // +2: search bar (index 0) + completed button (last)
        itemCount: _stages.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          // ── Index 0: search bar ────────────────────────────
          if (i == 0) {
            return TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search projects…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          }

          // ── Last item: completed button ────────────────────
          if (i == _stages.length + 1) {
            // "No results" message when search returns nothing
            if (_query.isNotEmpty && visibleCount == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No orders match "$_query"',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    'Completed Orders  (${completedOrders.length})',
                    style:
                        AppTypography.labelMedium.copyWith(color: Colors.white),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CompletedOrdersScreen(orders: completedOrders),
                    ),
                  ),
                ),
              ),
            );
          }

          // ── Stage group (indices 1 … _stages.length) ──────
          final stage = _stages[i - 1];
          final color = _stageColors[i - 1];
          final stageOrders = _process(_orders[stage] ?? []);

          // During an active search, hide stages with no matches
          if (_query.isNotEmpty && stageOrders.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(stage,
                      style: AppTypography.labelLarge.copyWith(color: color)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${stageOrders.length}',
                      style: AppTypography.caption.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (stageOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 4),
                  child: Text(
                    'No orders',
                    style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                )
              else
                ...stageOrders.map((order) {
                  final deliveryDate = _parseDate(order['deliveryDate']);
                  return InkWell(
                    onTap: () => context.push('/order-details', extra: order),
                    borderRadius: BorderRadius.circular(12),
                    child: PremiumCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.receipt_rounded,
                                color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HighlightText(
                                  text: order['title'] as String? ??
                                      'Untitled Order',
                                  query: _query,
                                  style: AppTypography.labelMedium,
                                ),
                                if ((order['schoolName'] as String? ?? '')
                                    .isNotEmpty)
                                  _HighlightText(
                                    text: order['schoolName'] as String,
                                    query: _query,
                                    style: AppTypography.bodySmall,
                                  ),
                                if (deliveryDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded,
                                            size: 10,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${deliveryDate.day}/${deliveryDate.month}/${deliveryDate.year}',
                                          style: AppTypography.caption.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.secondary.withOpacity(0.5)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

// ── Sort tile used in the sort bottom sheet ─────────────────────────
class _SortTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.secondary
        : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Icon(icon, color: color),
      title: Text(label,
          style: AppTypography.bodyMedium.copyWith(
              color: color, fontWeight: selected ? FontWeight.w700 : null)),
      trailing: selected
          ? Icon(Icons.check_rounded, color: AppColors.secondary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ── Inline text with highlighted search matches ─────────────────────
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText(
      {required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(text,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Text.rich(
      TextSpan(children: [
        if (idx > 0) TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: style.copyWith(
            backgroundColor: AppColors.secondary.withOpacity(0.25),
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (idx + q.length < text.length)
          TextSpan(text: text.substring(idx + q.length), style: style),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// -------------------------------------------------------------------
// COMPLETED ORDERS SCREEN
// -------------------------------------------------------------------
class CompletedOrdersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const CompletedOrdersScreen({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Orders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${orders.length} orders',
                  style:
                      AppTypography.caption.copyWith(color: AppColors.success),
                ),
              ),
            ),
          ),
        ],
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('No completed orders yet',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Orders marked as Delivered will appear here.',
                    style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final order = orders[i];
                return PremiumCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['title'] as String? ?? 'Untitled Order',
                              style: AppTypography.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order['schoolName'] as String? ?? '',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.success.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_shipping_rounded,
                                size: 12, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('Delivered',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.success)),
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

// -------------------------------------------------------------------
// ORDER DETAILS SCREEN
// -------------------------------------------------------------------
class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const _kBaseUrl = _kServerBase;

  late Map<String, dynamic> _order;
  bool _loading = true;
  bool _showAllRows = false; // for CSV expand/collapse

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadFullOrder();
  }

  Future<void> _loadFullOrder() async {
    final id = _order['id']?.toString() ?? _order['_id']?.toString();
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      debugPrint(
          '[OrderDetails] Loading order id=$id from $_kBaseUrl/api/vendor/orders/$id');
      final res = await _dio().get('$_kBaseUrl/api/vendor/orders/$id');
      debugPrint('[OrderDetails] Response ${res.statusCode}');
      if (mounted) {
        final data = res.data as Map<String, dynamic>;
        debugPrint('[OrderDetails] FULL ORDER: $data');
        debugPrint('[OrderDetails] images: ${data['images']}');
        debugPrint('[OrderDetails] orderImages: ${data['orderImages']}');
        debugPrint('[OrderDetails] attachments: ${data['attachments']}');
        debugPrint('[OrderDetails] excelFileName: ${data['excelFileName']}');
        setState(() {
          _order = data;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[OrderDetails] _loadFullOrder ERROR: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = _order['title'] as String? ?? 'Untitled Order';
    final clientName = _order['schoolName'] as String? ?? 'Unknown Client';
    final stage = _order['stage'] as String? ?? 'Draft';
    final deliveryDate = _order['deliveryDate'] as String? ?? 'N/A';
    final description = _order['description'] as String? ?? '';
    final productType = _order['productType'] as String? ?? '';
    final progress = (_order['progress'] as num? ?? 0).toInt();
    final images = [
      ...((_order['images'] as List?)?.cast<String>() ?? []),
      ...((_order['orderImages'] as List?)?.cast<String>() ?? []),
    ].where((url) => url.isNotEmpty).toSet().toList(); // deduplicate
    debugPrint('[OrderDetails] images(${images.length}): $images');
    final attachments = ((_order['attachments'] as List?)?.cast<String>() ?? [])
        .where((u) => u.isNotEmpty)
        .toList();
    final excelFileName = (_order['excelFileName'] as String? ?? '').trim();
    // excelData: backend stores rows as List<List<dynamic>> OR List<Map>.
    // Normalise to List<List<String>> for table display.
    final rawExcel = (_order['excelData'] as List?) ?? [];
    final List<List<String>> excelRows = rawExcel
        .map((row) {
          if (row is List) {
            return row.map((c) => c?.toString() ?? '').toList();
          } else if (row is Map) {
            return row.values.map((c) => c?.toString() ?? '').toList();
          }
          return <String>[];
        })
        .where((r) => r.isNotEmpty)
        .toList();
    // Derive headers: if first row looks like headers (from columnMappings or
    // variable fields names), use it; otherwise generate Col 1, Col 2 …
    List<String> excelHeaders = [];
    if (excelRows.isNotEmpty) {
      final rawHeaders = (_order['excelHeaders'] as List?);
      if (rawHeaders != null && rawHeaders.isNotEmpty) {
        excelHeaders = rawHeaders.map((h) => h?.toString() ?? '').toList();
      } else {
        // Use the first row as headers if it was stored that way,
        // otherwise auto-generate Col N labels.
        excelHeaders =
            List.generate(excelRows.first.length, (i) => 'Col ${i + 1}');
      }
    }
    final quantity = (_order['quantity'] as num? ?? 1).toInt();
    final unit = (_order['unit'] as String? ?? '').trim();
    final variableFields = ((_order['variableFields'] as List?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .where((f) => (f['name'] as String? ?? '').isNotEmpty)
        .toList();
    final columnMappings =
        (_order['columnMappings'] as Map<String, dynamic>?) ?? {};
    final displayFields = <Map<String, String>>[
      {'label': 'Client', 'value': clientName},
      if (productType.isNotEmpty)
        {'label': 'Product Type', 'value': productType},
      {'label': 'Stage', 'value': stage},
      {'label': 'Delivery', 'value': deliveryDate},
      {
        'label': 'Quantity',
        'value': unit.isNotEmpty ? '$quantity $unit' : '$quantity'
      },
      if (unit.isNotEmpty) {'label': 'Unit', 'value': unit},
      if (excelFileName.isNotEmpty)
        {'label': 'Data File', 'value': excelFileName},
      if (description.isNotEmpty)
        {'label': 'Description', 'value': description},
    ];
    final productName = _order['productName'] as String? ?? '';
    final productImage = _order['productImage'] as String? ?? '';
    final hasProduct = productName.isNotEmpty || productImage.isNotEmpty;
    final pricingMap = _order['pricing'] as Map<String, dynamic>?;
    final studentPrice = (pricingMap?['student'] as num?)?.toDouble() ?? 0;
    final teacherPrice = (pricingMap?['teacher'] as num?)?.toDouble() ?? 0;
    final staffPrice = (pricingMap?['staff'] as num?)?.toDouble() ?? 0;
    final otherPrice = (pricingMap?['other'] as num?)?.toDouble() ?? 0;
    final hasPricing = studentPrice > 0 ||
        teacherPrice > 0 ||
        staffPrice > 0 ||
        otherPrice > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with stage badge
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleLarge.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RoleBadge(label: stage, color: AppColors.primary),
                ],
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic Order Summary Card
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Summary', style: AppTypography.labelLarge),
                        const SizedBox(height: 12),
                        ...displayFields.map(
                          (f) => _FieldRow(
                            label: f['label']!,
                            value: f['value']!,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product Card — shows product image + name from catalogue
                  if (hasProduct) ...[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Product', style: AppTypography.labelLarge),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Product image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: productImage.isNotEmpty
                                    ? Image.network(
                                        ApiConfig.resolveImageUrl(productImage),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _productImagePlaceholder(),
                                        loadingBuilder: (_, child, prog) => prog ==
                                                null
                                            ? child
                                            : const SizedBox(
                                                width: 72,
                                                height: 72,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2))),
                                      )
                                    : _productImagePlaceholder(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (productName.isNotEmpty)
                                      Text(productName,
                                          style: AppTypography.labelMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    if (hasPricing) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (studentPrice > 0)
                                            _PriceChip(
                                                label: 'Student',
                                                price: studentPrice),
                                          if (teacherPrice > 0)
                                            _PriceChip(
                                                label: 'Teacher',
                                                price: teacherPrice),
                                          if (staffPrice > 0)
                                            _PriceChip(
                                                label: 'Staff',
                                                price: staffPrice),
                                          if (otherPrice > 0)
                                            _PriceChip(
                                                label: 'Other',
                                                price: otherPrice),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Variable Fields Card
                  if (variableFields.isNotEmpty) ...[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Variable Fields',
                              style: AppTypography.labelLarge),
                          const SizedBox(height: 12),
                          ...variableFields.map((f) {
                            final name = f['name']?.toString() ?? '';
                            final type = f['type']?.toString() ?? 'text';
                            final mapped =
                                columnMappings[name]?.toString() ?? '';
                            return _FieldRow(
                              label: name,
                              value: mapped.isNotEmpty
                                  ? 'Mapped: $mapped ($type)'
                                  : type,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Pricing Section
                  if (hasPricing) ...[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pricing', style: AppTypography.labelLarge),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Student',
                            value: '\u20B9${studentPrice.toStringAsFixed(0)}',
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Teacher',
                            value: '\u20B9${teacherPrice.toStringAsFixed(0)}',
                            icon: Icons.school_rounded,
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Staff',
                            value: '\u20B9${staffPrice.toStringAsFixed(0)}',
                            icon: Icons.badge_rounded,
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Other',
                            value: '\u20B9${otherPrice.toStringAsFixed(0)}',
                            icon: Icons.people_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Progress Section
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progress', style: AppTypography.labelLarge),
                            Text('$progress%',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100.0,
                            minHeight: 8,
                            color: AppColors.primary,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Images Section — only shown when images actually exist
                  if (images.isNotEmpty) ...[
                    Text('Order Images', style: AppTypography.labelLarge),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ApiConfig.resolveImageUrl(images[i]),
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 110,
                              height: 110,
                              color: AppColors.primary.withOpacity(0.08),
                              child: const Icon(Icons.broken_image_rounded,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 20),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.primary.withOpacity(0.7)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Order stage is managed from the admin panel',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primary.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Uploaded Files Section ─────────────────────────────
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.attach_file_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Uploaded Files',
                                  style: AppTypography.labelLarge),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${attachments.length}',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...attachments.asMap().entries.map((entry) {
                            final i = entry.key;
                            final url = entry.value;
                            final fileName = url.split('/').last;
                            final ext = fileName.contains('.')
                                ? fileName.split('.').last.toLowerCase()
                                : '';
                            IconData fileIcon;
                            Color fileColor;
                            switch (ext) {
                              case 'pdf':
                                fileIcon = Icons.picture_as_pdf_rounded;
                                fileColor = Colors.red;
                                break;
                              case 'doc':
                              case 'docx':
                                fileIcon = Icons.description_rounded;
                                fileColor = Colors.blue;
                                break;
                              case 'xls':
                              case 'xlsx':
                              case 'csv':
                                fileIcon = Icons.table_chart_rounded;
                                fileColor = Colors.green;
                                break;
                              case 'jpg':
                              case 'jpeg':
                              case 'png':
                              case 'gif':
                              case 'webp':
                                fileIcon = Icons.image_rounded;
                                fileColor = AppColors.primary;
                                break;
                              default:
                                fileIcon = Icons.insert_drive_file_rounded;
                                fileColor = Colors.blueGrey;
                            }
                            return Column(
                              children: [
                                if (i > 0)
                                  Divider(
                                      height: 1,
                                      color: Colors.grey.withOpacity(0.2)),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    // Build a full URL — stored value may
                                    // occasionally be just a filename or path.
                                    String fullUrl = url.trim();
                                    if (!fullUrl.startsWith('http://') &&
                                        !fullUrl.startsWith('https://')) {
                                      const base = 'http://72.62.241.170';
                                      fullUrl = fullUrl.startsWith('/')
                                          ? '$base$fullUrl'
                                          : '$base/uploads/order-files/$fullUrl';
                                    }
                                    final uri = Uri.tryParse(fullUrl);
                                    if (uri == null) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content:
                                              Text('Invalid URL: $fileName'),
                                          behavior: SnackBarBehavior.floating,
                                        ));
                                      }
                                      return;
                                    }
                                    try {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    } catch (_) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content:
                                              Text('Cannot open: $fileName'),
                                          behavior: SnackBarBehavior.floating,
                                        ));
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: fileColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(fileIcon,
                                              color: fileColor, size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fileName,
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                              Text(
                                                ext.toUpperCase().isEmpty
                                                    ? 'File'
                                                    : ext.toUpperCase(),
                                                style: AppTypography.caption
                                                    .copyWith(color: fileColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.open_in_new_rounded,
                                            size: 16,
                                            color: AppColors.primary
                                                .withOpacity(0.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // ── CSV / Excel Data Preview ───────────────────────────
                  if (excelRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.table_chart_rounded,
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  excelFileName.isNotEmpty
                                      ? excelFileName
                                      : 'Data File',
                                  style: AppTypography.labelLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${excelRows.length} rows',
                                  style: AppTypography.caption.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Horizontal scrollable table — show all or first 10
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 36,
                              dataRowMinHeight: 32,
                              dataRowMaxHeight: 48,
                              columnSpacing: 20,
                              headingTextStyle: AppTypography.caption.copyWith(
                                color: AppColors.secondary.withOpacity(0.65),
                                fontWeight: FontWeight.w700,
                              ),
                              dataTextStyle: AppTypography.bodySmall,
                              columns: excelHeaders
                                  .map((h) => DataColumn(
                                      label: Text(h,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              rows: (_showAllRows
                                      ? excelRows
                                      : excelRows.take(10).toList())
                                  .map((row) => DataRow(
                                        cells: List.generate(
                                          excelHeaders.length,
                                          (ci) => DataCell(Text(
                                            ci < row.length ? row[ci] : '',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          )),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          if (excelRows.length > 10) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showAllRows = !_showAllRows),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showAllRows
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showAllRows
                                        ? 'Show less'
                                        : '+ ${excelRows.length - 10} more rows — tap to expand',
                                    style: AppTypography.caption.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImagePlaceholder() => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory_2_outlined,
            color: AppColors.primary, size: 32),
      );
}

class _PriceChip extends StatelessWidget {
  final String label;
  final double price;
  const _PriceChip({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: \u20B9${price.toStringAsFixed(0)}',
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Label + value row without icon — used for dynamic field lists ───────────
class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.secondary.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for detail rows
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondary.withOpacity(0.6),
                  )),
              Text(value, style: AppTypography.labelMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------
// WORKFLOW STAGE DETAIL
// -------------------------------------------------------------------
class WorkflowStageDetailScreen extends StatefulWidget {
  final String stage;
  const WorkflowStageDetailScreen({super.key, required this.stage});

  @override
  State<WorkflowStageDetailScreen> createState() =>
      _WorkflowStageDetailScreenState();
}

class _WorkflowStageDetailScreenState extends State<WorkflowStageDetailScreen> {
  static const _kBaseUrl = _kServerBase;

  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final vendorId = await _currentVendorId();
      final response = await _dio().get(
        '$_kBaseUrl/api/vendor/orders',
        queryParameters: {'vendorId': vendorId},
      );
      final data = response.data as Map<String, dynamic>;
      final stageOrders =
          (data[widget.stage] as List? ?? []).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _orders = stageOrders;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[StageDetail] load error: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.stage} � Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientCard(
              gradient: AppColors.primaryGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.stage,
                      style: AppTypography.headlineMedium
                          .copyWith(color: Colors.white)),
                  Text('Stage Overview',
                      style: AppTypography.bodySmall
                          .copyWith(color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Orders in this stage', style: AppTypography.titleSmall),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator()))
            else if (_orders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No orders in this stage',
                    style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                  ),
                ),
              )
            else
              ..._orders.map((order) => PremiumCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        AppAvatar(
                            name: order['schoolName'] as String? ?? '?',
                            radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  order['title'] as String? ?? 'Untitled Order',
                                  style: AppTypography.labelMedium),
                              Text(order['schoolName'] as String? ?? '',
                                  style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            color: AppColors.primary, size: 18),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR SCHOOL LIST
// -------------------------------------------------------------------

class _VendorSchoolEntry {
  final String name;
  final String city;
  final String board;
  final int totalStudents;
  final Color color;
  final String clientId;
  final String principalId;
  const _VendorSchoolEntry({
    required this.name,
    required this.city,
    required this.board,
    required this.totalStudents,
    required this.color,
    this.clientId = '',
    this.principalId = '',
  });
}

class _VendorSchoolListScreen extends StatefulWidget {
  final List<_VendorSchoolEntry>? schools;
  final String vendorId;
  const _VendorSchoolListScreen({this.schools, this.vendorId = ''});

  @override
  State<_VendorSchoolListScreen> createState() =>
      _VendorSchoolListScreenState();
}

class _VendorSchoolListScreenState extends State<_VendorSchoolListScreen> {
  late List<_VendorSchoolEntry> _schools;
  final _codeCtrl = TextEditingController();
  bool _searching = false;

  static const _kColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.roleTeacher,
    AppColors.accent,
    AppColors.success,
  ];

  @override
  void initState() {
    super.initState();
    _schools = List.from(widget.schools ?? []);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSchoolByCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _searching = true);
    try {
      final token = await AuthService.instance.getStoredToken();
      final dio = _dioWithAuth(token);
      final r = await dio.get(
        '$_kServerBase/api/vendor/schools/lookup',
        queryParameters: {'code': code},
      );
      if (!mounted) return;
      final data = r.data as Map<String, dynamic>;
      if (data['found'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No school found with code "$code"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ));
        setState(() => _searching = false);
        return;
      }

      final principalId = (data['principalId'] ?? '') as String;
      if (_schools
          .any((s) => s.principalId == principalId && principalId.isNotEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This school is already in the list'),
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _searching = false);
        return;
      }

      final entry = _VendorSchoolEntry(
        name: (data['schoolName'] ?? code) as String,
        city: '',
        board: '',
        totalStudents: 0,
        color: _kColors[_schools.length % _kColors.length],
        principalId: principalId,
      );

      // Persist the link to the backend so it survives app restarts.
      if (principalId.isNotEmpty && widget.vendorId.isNotEmpty) {
        try {
          await dio.post(
            '$_kServerBase/api/vendor/schools/link',
            data: {'vendorId': widget.vendorId, 'principalId': principalId},
          );
        } catch (_) {
          // Non-fatal: the school is still shown locally this session.
        }
      }

      setState(() {
        _schools.add(entry);
        _searching = false;
      });
      _codeCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _removeSchool(_VendorSchoolEntry school) async {
    final principalId = school.principalId;
    // Only manually-linked schools (principalId set, no clientId) can be removed here.
    if (principalId.isEmpty) return;

    setState(() => _schools.removeWhere((s) => s.principalId == principalId));

    if (widget.vendorId.isNotEmpty) {
      try {
        final token = await AuthService.instance.getStoredToken();
        final dio = _dioWithAuth(token);
        await dio.delete(
          '$_kServerBase/api/vendor/schools/link',
          data: {'vendorId': widget.vendorId, 'principalId': principalId},
        );
      } catch (_) {
        // Non-fatal — local state already updated.
      }
    }
  }

  void _showAddSchoolDialog() {
    _codeCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.school_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Add School'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the school code to fetch and view the school\'s data.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'School Code',
                hintText: 'e.g. ABC123',
                prefixIcon:
                    const Icon(Icons.vpn_key_rounded, color: AppColors.primary),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: _searching
                ? null
                : () {
                    Navigator.of(ctx).pop();
                    _addSchoolByCode();
                  },
            icon: _searching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search_rounded, size: 18),
            label: const Text('Find School'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schools'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSchoolDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add School'),
      ),
      body: _schools.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No schools yet',
                      style: AppTypography.bodyMedium
                          .copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Tap "Add School" to get started',
                      style:
                          AppTypography.bodySmall.copyWith(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: _schools.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final school = _schools[i];
                final isManualLink =
                    school.principalId.isNotEmpty && school.clientId.isEmpty;
                final card = InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _VendorSchoolDetailScreen(school: school),
                  )),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: school.color.withOpacity(0.2), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: school.color.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: school.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.account_balance_rounded,
                            color: school.color, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(school.name,
                                style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface)),
                            const SizedBox(height: 3),
                            Text(
                                school.city.isNotEmpty
                                    ? school.city
                                    : 'Tap to view details',
                                style: AppTypography.bodySmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5))),
                          ],
                        ),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: school.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${school.totalStudents}',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: school.color,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 2),
                            Text('students',
                                style: AppTypography.caption.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.4))),
                          ]),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded,
                          color: school.color.withOpacity(0.6)),
                    ]),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 60 * i))
                    .fadeIn(duration: 220.ms);

                if (!isManualLink) return card;

                return Dismissible(
                  key: ValueKey(school.principalId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.link_off_rounded,
                        color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove School'),
                            content:
                                Text('Remove "${school.name}" from your list?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Remove',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) => _removeSchool(school),
                  child: card,
                );
              },
            ),
    );
  }
}

class _VendorSchoolDetailScreen extends StatefulWidget {
  final _VendorSchoolEntry school;
  const _VendorSchoolDetailScreen({required this.school});

  @override
  State<_VendorSchoolDetailScreen> createState() =>
      _VendorSchoolDetailScreenState();
}

class _VendorSchoolDetailScreenState extends State<_VendorSchoolDetailScreen> {
  bool _loading = true;
  int _classesCount = 0;
  int _teachersCount = 0;
  int _studentsCount = 0;
  int _staffCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final cid = widget.school.clientId;
    final pid = widget.school.principalId;
    if (cid.isEmpty && pid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final token = await AuthService.instance.getStoredToken();
      final dio = _dioWithAuth(token);
      final r = cid.isNotEmpty
          ? await dio
              .get('$_kServerBase/api/vendor/clients/$cid/school-summary')
          : await dio.get('$_kServerBase/api/vendor/schools/summary',
              queryParameters: {'principalId': pid});
      if (r.statusCode == 200) {
        final d = r.data as Map<String, dynamic>;
        setState(() {
          _classesCount = (d['classesCount'] as num?)?.toInt() ?? 0;
          _teachersCount = (d['teachersCount'] as num?)?.toInt() ?? 0;
          _studentsCount = (d['studentsCount'] as num?)?.toInt() ?? 0;
          _staffCount = (d['staffCount'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<_VendorSectionDef> get _sections => [
        _VendorSectionDef(
          icon: Icons.class_,
          title: 'Classes',
          count: _loading ? '...' : '$_classesCount',
          unit: 'classes',
          subtitle: 'Tap to view classes',
          color: AppColors.secondary,
        ),
        _VendorSectionDef(
          icon: Icons.person_rounded,
          title: 'Teachers',
          count: _loading ? '...' : '$_teachersCount',
          unit: 'teachers',
          subtitle: 'Tap to view teachers',
          color: AppColors.roleTeacher,
        ),
        _VendorSectionDef(
          icon: Icons.school_rounded,
          title: 'Students',
          count: _loading ? '...' : '$_studentsCount',
          unit: 'students',
          subtitle: 'Tap to view students',
          color: AppColors.primary,
        ),
        _VendorSectionDef(
          icon: Icons.badge_rounded,
          title: 'Staff',
          count: _loading ? '...' : '$_staffCount',
          unit: 'staff',
          subtitle: 'Tap to view staff',
          color: AppColors.accent,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final school = widget.school;
    final sections = _sections;
    return Scaffold(
      appBar: AppBar(
        title: Text(school.name),
        backgroundColor: school.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [school.color, school.color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(school.name,
                        style: AppTypography.labelLarge.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${school.city} \u2022 ${school.board}',
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
            ]),
          ).animate().fadeIn(duration: 250.ms),
          const SizedBox(height: 24),
          Text('Sections',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...sections.asMap().entries.map((e) {
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VendorSectionCard(
                def: s,
                onTap: () {
                  if (s.title == 'Classes') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _VendorClassListScreen(
                        clientId: school.clientId,
                        principalId: school.principalId,
                      ),
                    ));
                  } else {
                    final raw = s.title.toLowerCase();
                    final memberType = raw.endsWith('s')
                        ? raw.substring(0, raw.length - 1)
                        : raw;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _VendorSectionScreen(
                        title: s.title,
                        icon: s.icon,
                        color: s.color,
                        totalCountLabel: '${s.count} ${s.unit}',
                        clientId: school.clientId,
                        principalId: school.principalId,
                        memberType: memberType,
                      ),
                    ));
                  }
                },
              )
                  .animate(delay: Duration(milliseconds: 80 * e.key))
                  .fadeIn(duration: 250.ms)
                  .slideX(begin: 0.04, end: 0),
            );
          }),
        ],
      ),
    );
  }
}

class _VendorSectionDef {
  final IconData icon;
  final String title;
  final String count;
  final String unit;
  final String subtitle;
  final Color color;
  const _VendorSectionDef({
    required this.icon,
    required this.title,
    required this.count,
    required this.unit,
    required this.subtitle,
    required this.color,
  });
}

// -- Section Card -----------------------------------------------------

class _VendorSectionCard extends StatelessWidget {
  final _VendorSectionDef def;
  final VoidCallback onTap;
  const _VendorSectionCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                color: def.color.withOpacity(isDark ? 0.08 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: def.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(def.icon, color: def.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.title,
                        style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 3),
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
              child: Text(def.count,
                  style: AppTypography.titleSmall
                      .copyWith(color: def.color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: def.color.withOpacity(0.6)),
          ]),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR CLASS LIST SCREEN
// -------------------------------------------------------------------

class _VendorClassListScreen extends StatefulWidget {
  final String clientId;
  final String principalId;
  const _VendorClassListScreen({required this.clientId, this.principalId = ''});

  @override
  State<_VendorClassListScreen> createState() => _VendorClassListScreenState();
}

class _VendorClassListScreenState extends State<_VendorClassListScreen> {
  bool _loading = true;
  List<String> _classes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final cid = widget.clientId;
    final pid = widget.principalId;
    if (cid.isEmpty && pid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final token = await AuthService.instance.getStoredToken();
      final dio = _dioWithAuth(token);
      final r = cid.isNotEmpty
          ? await dio.get(
              '$_kServerBase/api/vendor/clients/${widget.clientId}/school-classes')
          : await dio.get('$_kServerBase/api/vendor/schools/classes',
              queryParameters: {'principalId': pid});
      if (r.statusCode == 200) {
        final data = r.data as Map<String, dynamic>;
        setState(() {
          _classes = List<String>.from(data['classes'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load classes';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: AppTypography.bodyMedium))
              : _classes.isEmpty
                  ? Center(
                      child: Text('No classes found',
                          style: AppTypography.bodyMedium))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _classes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final cls = _classes[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.18),
                                width: 1.5),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.class_,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Text(cls, style: AppTypography.labelLarge),
                          ]),
                        );
                      },
                    ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR SECTION SCREEN  (Teachers / Students / Staff)
// -------------------------------------------------------------------

class _VendorSectionScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String totalCountLabel;
  final String clientId;
  final String principalId;
  final String memberType;
  const _VendorSectionScreen({
    required this.title,
    required this.icon,
    required this.color,
    required this.totalCountLabel,
    required this.clientId,
    this.principalId = '',
    required this.memberType,
  });

  static final _cats = [
    ('All', Icons.people_rounded),
    ('Without Photo', Icons.no_photography_rounded),
    ('Unchecked Data', Icons.pending_outlined),
    ('Ready to Print', Icons.print_rounded),
    ('Printing', Icons.local_print_shop_rounded),
    ('Delivered', Icons.check_circle_rounded),
  ];

  static const _catColors = [
    AppColors.primary,
    AppColors.warning,
    AppColors.accent,
    AppColors.success,
    AppColors.secondary,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(title),
          backgroundColor: color,
          foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w700, color: color)),
                    Text(totalCountLabel,
                        style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6))),
                  ])),
            ]),
          ).animate().fadeIn(duration: 250.ms),
          const SizedBox(height: 20),
          Text('Filter by Status',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ..._cats.asMap().entries.map((e) {
            final (label, catIcon) = e.value;
            final catColor = _catColors[e.key];
            final count = 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _VendorMemberListScreen(
                    category: '\$title \u2013 \$label',
                    section: title,
                    count: count,
                    icon: catIcon,
                    color: catColor,
                    clientId: clientId,
                    principalId: principalId,
                    memberType: memberType,
                  ),
                )),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: catColor.withOpacity(0.18), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: catColor.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(children: [
                    Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(catIcon, color: catColor, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(label,
                            style: AppTypography.labelLarge.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurface))),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('\$count',
                            style: AppTypography.labelSmall
                                .copyWith(color: catColor))),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        color: catColor.withOpacity(0.5), size: 20),
                  ]),
                ),
              ).animate(delay: Duration(milliseconds: 50 * e.key)).fadeIn(),
            );
          }),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR MEMBER MODEL
// -------------------------------------------------------------------

class _VMemberEntry {
  final int id;
  String name;
  String classOrDept;
  String phone;
  String address;
  bool isBlocked = false;
  _VMemberEntry(
      {required this.id,
      required this.name,
      required this.classOrDept,
      required this.phone,
      required this.address});
}

// -------------------------------------------------------------------
// VENDOR MEMBER LIST SCREEN
// -------------------------------------------------------------------

class _VendorMemberListScreen extends StatefulWidget {
  final String category;
  final String section;
  final int count;
  final IconData icon;
  final Color color;
  final String clientId;
  final String principalId;
  final String memberType;
  const _VendorMemberListScreen({
    required this.category,
    required this.section,
    required this.count,
    required this.icon,
    required this.color,
    required this.clientId,
    this.principalId = '',
    required this.memberType,
  });
  @override
  State<_VendorMemberListScreen> createState() =>
      _VendorMemberListScreenState();
}

class _VendorMemberListScreenState extends State<_VendorMemberListScreen> {
  late List<_VMemberEntry> _items;
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _items = [];
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final cid = widget.clientId;
    final pid = widget.principalId;
    if (cid.isEmpty && pid.isEmpty) {
      setState(() => _loadingMembers = false);
      return;
    }
    try {
      final token = await AuthService.instance.getStoredToken();
      final dio = _dioWithAuth(token);
      final r = cid.isNotEmpty
          ? await dio.get(
              '$_kServerBase/api/vendor/clients/${widget.clientId}/school-members',
              queryParameters: {'type': widget.memberType},
            )
          : await dio.get(
              '$_kServerBase/api/vendor/schools/members',
              queryParameters: {'principalId': pid, 'type': widget.memberType},
            );
      if (r.statusCode == 200) {
        final data = r.data as Map<String, dynamic>;
        final list = (data['members'] as List<dynamic>?) ?? [];
        setState(() {
          _items = list.asMap().entries.map((e) {
            final m = e.value as Map<String, dynamic>;
            return _VMemberEntry(
              id: e.key,
              name: (m['name'] ?? '') as String,
              classOrDept: (m['classOrDept'] ?? '') as String,
              phone: (m['phone'] ?? '') as String,
              address: '',
            );
          }).toList();
          _loadingMembers = false;
        });
      } else {
        setState(() => _loadingMembers = false);
      }
    } catch (_) {
      setState(() => _loadingMembers = false);
    }
  }

  void _editItem(int index) {
    final item = _items[index];
    final isTeacher = widget.section.toLowerCase().contains('teacher');
    final isStaff = widget.section.toLowerCase().contains('staff');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _VEditMemberSheet(
        item: item,
        color: widget.color,
        isTeacher: isTeacher,
        isStaff: isStaff,
        onSaved: (name, dept, phone, address) {
          setState(() {
            _items[index].name = name;
            _items[index].classOrDept = dept;
            _items[index].phone = phone;
            _items[index].address = address;
          });
        },
      ),
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text('Confirm Delete'),
        ]),
        content:
            Text('Delete "\${_items[index].name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!mounted) return;
              setState(() => _items.removeAt(index));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Record deleted'),
                  behavior: SnackBarBehavior.floating));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleBlock(int index) {
    final item = _items[index];
    final willBlock = !item.isBlocked;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
              willBlock
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              color: willBlock ? AppColors.warning : AppColors.success,
              size: 22),
          const SizedBox(width: 8),
          Text(willBlock ? 'Block User' : 'Unblock User'),
        ]),
        content: Text(willBlock
            ? '"\${item.name}" will be blocked and cannot log in.'
            : '"\${item.name}" will be unblocked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    willBlock ? AppColors.warning : AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!mounted) return;
              setState(() => _items[index].isBlocked = willBlock);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(willBlock
                      ? '\${item.name} blocked'
                      : '\${item.name} unblocked'),
                  behavior: SnackBarBehavior.floating));
            },
            child: Text(willBlock ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
  }

  void _showImport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) =>
          _VImportSheet(section: widget.section, color: widget.color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showImport,
              icon: const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Import',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _loadingMembers
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 72, color: widget.color.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('All caught up!',
                          style: AppTypography.titleSmall
                              .copyWith(color: widget.color)),
                      Text('No records in this category',
                          style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5))),
                    ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final day = (i % 28) + 1;
                    final month = ['Jan', 'Feb', 'Mar', 'Apr'][(i ~/ 7) % 4];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: item.isBlocked
                            ? Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.7)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isBlocked
                              ? Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3)
                              : widget.color.withOpacity(0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.isBlocked
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.1)
                                : widget.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                              child: Text(
                            item.name.isNotEmpty ? item.name[0] : '?',
                            style: AppTypography.labelLarge.copyWith(
                              color: item.isBlocked
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.4)
                                  : widget.color,
                            ),
                          )),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.name,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: item.isBlocked
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.45)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  )),
                              Text(item.classOrDept,
                                  style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5))),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 11,
                                    color: widget.color.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text('$day $month 2025',
                                    style: AppTypography.caption.copyWith(
                                        color: widget.color.withOpacity(0.7),
                                        fontWeight: FontWeight.w500)),
                              ]),
                            ])),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (item.isBlocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text('Blocked',
                                      style: AppTypography.caption.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                          fontWeight: FontWeight.w600)),
                                )
                              else
                                RoleBadge(
                                  label: widget.category.contains('Delivered')
                                      ? 'Done'
                                      : widget.category.contains('Printing')
                                          ? 'Printing'
                                          : widget.category.contains('Ready')
                                              ? 'Ready'
                                              : 'Pending',
                                  color: widget.color,
                                ),
                              if (widget.section
                                      .toLowerCase()
                                      .contains('teacher') &&
                                  widget.category.contains('\u2013 All')) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(28))),
                                    builder: (_) =>
                                        const _VAssignClassToTeacherSheet(),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.roleTeacher
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.roleTeacher
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.assignment_ind_rounded,
                                              size: 12,
                                              color: AppColors.roleTeacher),
                                          const SizedBox(width: 4),
                                          Text('Assign',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color:
                                                          AppColors.roleTeacher,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                        ]),
                                  ),
                                ),
                              ],
                              if (widget.section
                                      .toLowerCase()
                                      .contains('staff') &&
                                  widget.category.contains('\u2013 All')) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(28))),
                                    builder: (_) => _VAssignStaffRoleSheet(
                                        staffName: item.name,
                                        currentRole: item.classOrDept),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.accent
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.manage_accounts_rounded,
                                              size: 12,
                                              color: AppColors.accent),
                                          const SizedBox(width: 4),
                                          Text('Assign Role',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                      color: AppColors.accent,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                        ]),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _editItem(i);
                                  if (v == 'delete') _deleteItem(i);
                                  if (v == 'block') _toggleBlock(i);
                                },
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.more_vert_rounded,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5)),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 10),
                                        Text('Edit')
                                      ])),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline_rounded,
                                            size: 18, color: AppColors.error),
                                        SizedBox(width: 10),
                                        Text('Delete',
                                            style: TextStyle(
                                                color: AppColors.error)),
                                      ])),
                                  PopupMenuItem(
                                      value: 'block',
                                      child: Row(children: [
                                        Icon(
                                            item.isBlocked
                                                ? Icons
                                                    .check_circle_outline_rounded
                                                : Icons.block_rounded,
                                            size: 18,
                                            color: item.isBlocked
                                                ? AppColors.success
                                                : AppColors.warning),
                                        const SizedBox(width: 10),
                                        Text(
                                            item.isBlocked
                                                ? 'Unblock'
                                                : 'Block',
                                            style: TextStyle(
                                                color: item.isBlocked
                                                    ? AppColors.success
                                                    : AppColors.warning)),
                                      ])),
                                ],
                              ),
                            ]),
                      ]),
                    ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn();
                  },
                ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR EDIT MEMBER SHEET
// -------------------------------------------------------------------

class _VEditMemberSheet extends StatefulWidget {
  final _VMemberEntry item;
  final Color color;
  final bool isTeacher;
  final bool isStaff;
  final void Function(String name, String dept, String phone, String address)
      onSaved;
  const _VEditMemberSheet(
      {required this.item,
      required this.color,
      required this.isTeacher,
      required this.isStaff,
      required this.onSaved});
  @override
  State<_VEditMemberSheet> createState() => _VEditMemberSheetState();
}

class _VEditMemberSheetState extends State<_VEditMemberSheet> {
  static const _staffRoles = [
    'Coordinator',
    'Lab In-charge',
    'Librarian',
    'Admin',
    'Security',
    'Canteen'
  ];
  late final TextEditingController _nameCtrl,
      _classCtrl,
      _phoneCtrl,
      _addressCtrl;
  String? _selectedStaffRole;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _classCtrl = TextEditingController(text: widget.item.classOrDept);
    _phoneCtrl = TextEditingController(text: widget.item.phone);
    _addressCtrl = TextEditingController(text: widget.item.address);
    if (widget.isStaff) {
      _selectedStaffRole = _staffRoles.contains(widget.item.classOrDept)
          ? widget.item.classOrDept
          : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      [TextInputType? kb]) {
    final color = widget.color;
    return TextField(
      controller: ctrl,
      keyboardType: kb,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: color),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: color, width: 2)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final deptLabel = widget.isTeacher
        ? 'Subject / Class'
        : widget.isStaff
            ? 'Department'
            : 'Class & Section';
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.edit_rounded, color: color, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Edit � \${widget.item.name}',
                        style: AppTypography.titleMedium
                            .copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 24),
              _field(_nameCtrl, 'Full Name', Icons.person_outlined),
              const SizedBox(height: 16),
              if (widget.isStaff) ...[
                Text('Staff Role',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _staffRoles.map((r) {
                      final sel = _selectedStaffRole == r;
                      final os = Theme.of(context).colorScheme.onSurface;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStaffRole = r),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? color.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: sel ? color : os.withOpacity(0.25),
                                  width: sel ? 1.6 : 1.2),
                            ),
                            child: Text(r,
                                style: AppTypography.labelSmall.copyWith(
                                    color: sel ? color : os.withOpacity(0.75),
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500))),
                      );
                    }).toList()),
                const SizedBox(height: 16),
              ] else ...[
                _field(_classCtrl, deptLabel, Icons.class_),
                const SizedBox(height: 16),
              ],
              _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                  TextInputType.phone),
              const SizedBox(height: 16),
              _field(_addressCtrl, 'Address', Icons.location_on_outlined),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onSaved(
                      _nameCtrl.text.trim().isEmpty
                          ? widget.item.name
                          : _nameCtrl.text.trim(),
                      widget.isStaff
                          ? (_selectedStaffRole ?? widget.item.classOrDept)
                          : (_classCtrl.text.trim().isEmpty
                              ? widget.item.classOrDept
                              : _classCtrl.text.trim()),
                      _phoneCtrl.text.trim().isEmpty
                          ? widget.item.phone
                          : _phoneCtrl.text.trim(),
                      _addressCtrl.text.trim().isEmpty
                          ? widget.item.address
                          : _addressCtrl.text.trim(),
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Record updated'),
                        behavior: SnackBarBehavior.floating));
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                ),
              ),
            ]),
      ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR IMPORT SHEET
// -------------------------------------------------------------------

class _VImportSheet extends StatefulWidget {
  final String section;
  final Color color;
  const _VImportSheet({required this.section, required this.color});
  @override
  State<_VImportSheet> createState() => _VImportSheetState();
}

class _VImportSheetState extends State<_VImportSheet> {
  String? _fileName;
  bool _loading = false;

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
      if (result != null && result.files.isNotEmpty)
        setState(() => _fileName = result.files.first.name);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.upload_file_rounded,
                        color: color, size: 22)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Import \${widget.section}',
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text('via Excel / CSV',
                      style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5))),
                ]),
              ]),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expected Columns',
                          style: AppTypography.labelMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      ...[
                        ('A', 'Name', 'e.g. Rahul Sharma'),
                        ('B', 'Class/Dept', 'e.g. Class 9-A'),
                        ('C', 'Phone', 'e.g. +91 9876543210'),
                        ('D', 'Role', 'e.g. Student / Teacher'),
                      ].map((col) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Center(
                                      child: Text(col.$1,
                                          style: AppTypography.labelSmall
                                              .copyWith(color: color)))),
                              const SizedBox(width: 10),
                              Text('${col.$2}: ',
                                  style: AppTypography.labelSmall
                                      .copyWith(fontWeight: FontWeight.w600)),
                              Expanded(
                                  child: Text(col.$3,
                                      style: AppTypography.bodySmall.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.55)))),
                            ]),
                          )),
                    ]),
              ),
              const SizedBox(height: 20),
              if (_fileName != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_fileName!,
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.success))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: _loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color))
                      : Icon(Icons.folder_open_rounded, color: color),
                  label: Text(
                      _loading
                          ? 'Opening�'
                          : _fileName == null
                              ? 'Choose .xlsx or .csv'
                              : 'Choose different file',
                      style: TextStyle(color: color)),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _fileName == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '\${widget.section} imported from \$_fileName'),
                              behavior: SnackBarBehavior.floating));
                        },
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Import Data'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: color.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                ),
              ),
            ]),
      ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR ASSIGN CLASS TO TEACHER SHEET
// -------------------------------------------------------------------

class _VAssignClassToTeacherSheet extends StatefulWidget {
  const _VAssignClassToTeacherSheet();
  @override
  State<_VAssignClassToTeacherSheet> createState() =>
      _VAssignClassToTeacherSheetState();
}

class _VAssignClassToTeacherSheetState
    extends State<_VAssignClassToTeacherSheet> {
  static const _classList = [
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10'
  ];
  static const _sectionList = ['A', 'B', 'C', 'D'];
  static const _teacherRoles = ['Class Teacher', 'Subject Teacher'];
  static const _teachers = [
    ('Priya Nair', 'Mathematics'),
    ('Amit Sharma', 'Science'),
    ('Sunita Verma', 'English'),
    ('Rajesh Kumar', 'Hindi'),
    ('Pooja Singh', 'Social Studies'),
  ];

  String? _selClass, _selSection, _selRole, _selTeacher;

  Widget _chip(String label, bool sel, Color color, VoidCallback onTap) {
    final os = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? color : os.withOpacity(0.25),
                width: sel ? 1.6 : 1.2),
          ),
          child: Text(label,
              style: AppTypography.labelSmall.copyWith(
                  color: sel ? color : os.withOpacity(0.75),
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500))),
    );
  }

  bool get _canSave =>
      _selTeacher != null &&
      _selClass != null &&
      _selSection != null &&
      _selRole != null;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.roleTeacher;
    final os = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                          color: os.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.assignment_ind_rounded,
                        color: color, size: 22)),
                const SizedBox(width: 12),
                Text('Assign Class to Teacher',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 24),
              Text('Select Teacher',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ..._teachers.map((t) {
                final (name, subject) = t;
                final sel = _selTeacher == name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selTeacher = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withOpacity(0.08)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? color : os.withOpacity(0.15),
                            width: sel ? 1.8 : 1.2),
                      ),
                      child: Row(children: [
                        Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: color.withOpacity(sel ? 0.18 : 0.1),
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text(name[0],
                                    style: AppTypography.labelLarge.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.w700)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(name,
                                  style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: sel ? color : null)),
                              Text(subject,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: os.withOpacity(0.5))),
                            ])),
                        if (sel)
                          const Icon(Icons.check_circle_rounded,
                              color: color, size: 20),
                      ]),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text('Teacher Role',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _teacherRoles
                      .map((r) => _chip(r, _selRole == r, color,
                          () => setState(() => _selRole = r)))
                      .toList()),
              const SizedBox(height: 20),
              Text('Select Class',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _classList
                      .map((c) => _chip(c, _selClass == c, color,
                          () => setState(() => _selClass = c)))
                      .toList()),
              const SizedBox(height: 20),
              Text('Select Section',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sectionList
                      .map((s) => _chip('Section \$s', _selSection == s, color,
                          () => setState(() => _selSection = s)))
                      .toList()),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _canSave
                      ? () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '\$_selTeacher assigned as \$_selRole to \$_selClass � Section \$_selSection'),
                              behavior: SnackBarBehavior.floating));
                        }
                      : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Assign Class'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: color.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                ),
              ),
            ]),
      ),
    );
  }
}

// -------------------------------------------------------------------
// VENDOR ASSIGN STAFF ROLE SHEET
// -------------------------------------------------------------------

class _VAssignStaffRoleSheet extends StatefulWidget {
  final String staffName;
  final String currentRole;
  const _VAssignStaffRoleSheet(
      {required this.staffName, required this.currentRole});
  @override
  State<_VAssignStaffRoleSheet> createState() => _VAssignStaffRoleSheetState();
}

class _VAssignStaffRoleSheetState extends State<_VAssignStaffRoleSheet> {
  static const _roles = [
    'Coordinator',
    'Lab In-charge',
    'Librarian',
    'Admin',
    'Security',
    'Canteen',
    'Peon',
    'Accountant',
    'Receptionist',
    'Driver'
  ];
  late String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole =
        _roles.contains(widget.currentRole) ? widget.currentRole : null;
  }

  Widget _chip(String label) {
    final sel = _selectedRole == label;
    const color = AppColors.accent;
    final os = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = label),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? color : os.withOpacity(0.25),
                width: sel ? 1.6 : 1.2),
          ),
          child: Text(label,
              style: AppTypography.labelSmall.copyWith(
                  color: sel ? color : os.withOpacity(0.75),
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500))),
    );
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.accent;
    final os = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                          color: os.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.manage_accounts_rounded,
                        color: color, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Assign Staff Role',
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(widget.staffName,
                          style: AppTypography.bodySmall
                              .copyWith(color: os.withOpacity(0.55)),
                          overflow: TextOverflow.ellipsis),
                    ])),
              ]),
              const SizedBox(height: 24),
              Text('Select Role',
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roles.map(_chip).toList()),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _selectedRole == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '\${widget.staffName} assigned as \$_selectedRole'),
                              behavior: SnackBarBehavior.floating));
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Assign Role'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: color.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                ),
              ),
            ]),
      ),
    );
  }
}
