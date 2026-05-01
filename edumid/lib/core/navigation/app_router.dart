import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Auth
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';

// Student
import '../../features/student/screens/student_shell.dart';
import '../../features/student/screens/student_dashboard_screen.dart';
import '../../features/student/screens/student_id_card_screen.dart';
import '../../features/student/screens/id_card_zoom_screen.dart';
import '../../features/student/screens/download_pdf_screen.dart';
import '../../features/student/screens/share_id_card_screen.dart';
import '../../features/student/screens/digital_vcard_screen.dart';
import '../../features/student/screens/qr_verification_screen.dart';
import '../../features/student/screens/student_notifications_screen.dart';
import '../../features/student/screens/student_own_profile_screen.dart';
import '../../features/student/screens/student_attendance_screen.dart';
import '../../features/student/screens/student_correction_request_screen.dart';
import '../../features/student/screens/student_reprint_request_screen.dart';

// Teacher
import '../../features/teacher/screens/teacher_screens.dart'
    show
        TeacherDashboardScreen,
        TeacherShell,
        TeacherDataScreen,
        TeacherAttendanceScreen,
        TeacherProfileScreen,
        PrintingProgressScreen;
import '../../features/teacher/screens/student_list_screen.dart';
import '../../features/teacher/screens/class_filter_screen.dart';
import '../../features/teacher/screens/search_student_screen.dart';
import '../../features/teacher/screens/student_profile_screen.dart';
import '../../features/teacher/screens/edit_student_screen.dart';
import '../../features/teacher/screens/upload_photo_screen.dart';
import '../../features/teacher/screens/camera_capture_screen.dart';
import '../../features/teacher/screens/crop_photo_screen.dart';
import '../../features/teacher/screens/data_verification_screen.dart';
import '../../features/teacher/screens/correction_success_screen.dart';
import '../../features/teacher/screens/teacher_corrections_overview_screen.dart';
import '../../features/teacher/screens/teacher_class_corrections_screen.dart';
import '../../features/teacher/screens/teacher_correction_detail_screen.dart';
import '../../features/teacher/screens/teacher_stat_detail_screens.dart';
import '../../features/teacher/screens/teacher_reprint_requests_screen.dart';

// Principal
import '../../features/principal/screens/principal_screens.dart';

// Vendor
import '../../features/vendor/screens/vendor_shell.dart';
import '../../features/vendor/screens/vendor_dashboard_screen.dart';
import '../../features/vendor/screens/client_list_screen.dart';
import '../../features/vendor/screens/add_client_screen.dart';
import '../../features/vendor/screens/client_details_screen.dart';
import '../../features/vendor/screens/vendor_screens.dart'
    show
        CreateOrderScreen,
        ProjectBoardScreen,
        OrderDetailsScreen,
        WorkflowStageDetailScreen,
        UploadExcelScreen,
        UploadPhotosScreen,
        BulkPhotoMatchingScreen;
import '../../features/vendor/screens/vendor_profile_screen.dart';

// Notifications
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/notifications/screens/activity_feed_screen.dart';
import '../../features/notifications/screens/notification_detail_screen.dart';

// Settings
import '../../features/settings/screens/edit_profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/theme_settings_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/help_support_screen.dart';
import '../../features/settings/screens/faq_screen.dart';
import '../../features/settings/screens/about_screen.dart';

// Auth guard
import 'auth_session.dart';
import '../constants/app_constants.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _studentShellKey = GlobalKey<NavigatorState>();
  static final _teacherShellKey = GlobalKey<NavigatorState>();
  static final _principalShellKey = GlobalKey<NavigatorState>();
  static final _vendorShellKey = GlobalKey<NavigatorState>();

  // ── Role guard ──────────────────────────────────────────────────────────────
  static const _authPaths = {
    '/',
    '/login',
    '/signup',
  };

  static String? _redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;

    // Auth screens are always reachable.
    if (_authPaths.contains(path)) return null;

    // Infer role from the URL when it hasn't been set yet (e.g. session restore
    // or hot-restart in development navigate directly to a role path).
    AuthSession.inferFromPath(path);

    final role = AuthSession.role;
    if (role == null) return '/login';

    // Block any attempt to land on another role's route tree.
    const prefixes = {
      UserRole.student: '/student',
      UserRole.teacher: '/teacher',
      UserRole.principal: '/principal',
      UserRole.vendor: '/vendor',
    };
    final myPrefix = prefixes[role]!;
    for (final entry in prefixes.entries) {
      if (entry.key == role) continue;
      final other = entry.value;
      if (path == other || path.startsWith('$other/')) return myPrefix;
    }

    // Redirect legacy shared /profile → role-specific profile.
    if (path == '/profile') return '$myPrefix/profile';

    return null;
  }

  // ── Router ──────────────────────────────────────────────────────────────────
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: _redirect,
    routes: [
      // ── Auth (outside all shells) ──────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SignupScreen(),
        ),
      ),

      // ── Student Shell ─────────────────────────────────────────
      ShellRoute(
        navigatorKey: _studentShellKey,
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.studentDashboard,
            builder: (c, s) => const StudentDashboardScreen(),
            routes: [
              GoRoute(
                path: 'id-card',
                builder: (c, s) => const StudentIdCardScreen(),
                routes: [
                  GoRoute(
                      path: 'zoom',
                      builder: (c, s) => const IdCardZoomScreen()),
                  GoRoute(
                      path: 'download',
                      builder: (c, s) => const DownloadPdfScreen()),
                  GoRoute(
                      path: 'share',
                      builder: (c, s) => const ShareIdCardScreen()),
                ],
              ),
              GoRoute(
                  path: 'vcard', builder: (c, s) => const DigitalVcardScreen()),
              GoRoute(
                  path: 'qr-verify',
                  builder: (c, s) => const QrVerificationScreen()),
              GoRoute(
                  path: 'attendance',
                  builder: (c, s) => const StudentAttendanceScreen()),
              GoRoute(
                  path: 'correction-request',
                  builder: (c, s) => const StudentCorrectionRequestScreen()),
              GoRoute(
                  path: 'reprint-request',
                  builder: (c, s) => const StudentReprintRequestScreen()),
            ],
          ),
          GoRoute(
            path: AppRoutes.studentNotifications,
            builder: (c, s) => const StudentNotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentProfile,
            builder: (c, s) => const StudentOwnProfileScreen(),
            routes: [
              GoRoute(
                  path: 'edit', builder: (c, s) => const EditProfileScreen()),
              GoRoute(
                path: 'settings',
                builder: (c, s) => const SettingsScreen(),
                routes: [
                  GoRoute(
                      path: 'theme',
                      builder: (c, s) => const ThemeSettingsScreen()),
                  GoRoute(
                      path: 'notifications',
                      builder: (c, s) => const NotificationSettingsScreen()),
                ],
              ),
              GoRoute(
                  path: 'help', builder: (c, s) => const HelpSupportScreen()),
              GoRoute(path: 'faq', builder: (c, s) => const FaqScreen()),
              GoRoute(path: 'about', builder: (c, s) => const AboutScreen()),
            ],
          ),
        ],
      ),

      // ── Teacher Shell ─────────────────────────────────────────
      ShellRoute(
        navigatorKey: _teacherShellKey,
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.teacherDashboard,
            builder: (c, s) => const TeacherDashboardScreen(),
            routes: [
              GoRoute(
                path: 'reprint-requests',
                builder: (c, s) => const TeacherReprintRequestsScreen(),
              ),
              GoRoute(
                path: 'dispatch',
                builder: (c, s) => const DispatchStatusScreen(),
              ),
              GoRoute(
                path: 'corrections',
                builder: (c, s) => const TeacherCorrectionsOverviewScreen(),
                routes: [
                  GoRoute(
                    path: 'class/:className',
                    builder: (c, s) => TeacherClassCorrectionsScreen(
                      className: s.pathParameters['className']!,
                    ),
                  ),
                  GoRoute(
                    path: ':requestId',
                    builder: (c, s) => TeacherCorrectionDetailScreen(
                      requestId: s.pathParameters['requestId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'pending-photos',
                builder: (c, s) => const PendingPhotosScreen(),
              ),
              GoRoute(
                path: 'unchecked-data',
                builder: (c, s) => const UncheckedDataScreen(),
              ),
              GoRoute(
                path: 'printing-ready',
                builder: (c, s) => const ReadyToPrintScreen(),
              ),
              GoRoute(
                path: 'printing-progress',
                builder: (c, s) => const PrintingProgressScreen(),
              ),
              GoRoute(
                path: 'printing',
                builder: (c, s) => const PrintingScreen(),
              ),
              GoRoute(
                path: 'delivered',
                builder: (c, s) => const DeliveredScreen(),
              ),
              GoRoute(
                path: 'students',
                builder: (c, s) => const StudentListScreen(),
                routes: [
                  // ── Literal routes FIRST (must be before :studentId) ──
                  GoRoute(
                    path: 'filter',
                    builder: (c, s) => const ClassFilterScreen(),
                  ),
                  GoRoute(
                    path: 'search',
                    builder: (c, s) => const SearchStudentScreen(),
                  ),
                  GoRoute(
                    path: 'id-cards-ready',
                    builder: (c, s) => const IdCardsReadyScreen(),
                  ),
                  // ── Parameterised route LAST ──────────────────────────
                  GoRoute(
                    path: ':studentId',
                    builder: (c, s) => StudentProfileScreen(
                      studentId: s.pathParameters['studentId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (c, s) => EditStudentScreen(
                          studentId: s.pathParameters['studentId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'upload-photo',
                        builder: (c, s) => UploadPhotoScreen(
                          studentId: s.pathParameters['studentId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'camera',
                            builder: (c, s) => CameraCaptureScreen(
                              studentId: s.pathParameters['studentId']!,
                            ),
                          ),
                          GoRoute(
                            path: 'crop',
                            builder: (c, s) => CropPhotoScreen(
                              studentId: s.pathParameters['studentId']!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'verify',
                        builder: (c, s) => StudentVerifyScreen(
                          studentId: s.pathParameters['studentId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'correction',
                        builder: (c, s) => DataVerificationScreen(
                          studentId: s.pathParameters['studentId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'correction-success',
                        builder: (c, s) => const CorrectionSuccessScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.teacherData,
            builder: (c, s) => const TeacherDataScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherAttendance,
            builder: (c, s) => const TeacherAttendanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.teacherProfile,
            builder: (c, s) => const TeacherProfileScreen(),
            routes: [
              GoRoute(
                  path: 'edit', builder: (c, s) => const EditProfileScreen()),
              GoRoute(
                path: 'settings',
                builder: (c, s) => const SettingsScreen(),
                routes: [
                  GoRoute(
                      path: 'theme',
                      builder: (c, s) => const ThemeSettingsScreen()),
                  GoRoute(
                      path: 'notifications',
                      builder: (c, s) => const NotificationSettingsScreen()),
                ],
              ),
              GoRoute(
                  path: 'help', builder: (c, s) => const HelpSupportScreen()),
              GoRoute(path: 'faq', builder: (c, s) => const FaqScreen()),
              GoRoute(path: 'about', builder: (c, s) => const AboutScreen()),
            ],
          ),
        ],
      ),

      // ── Principal Shell ───────────────────────────────────────
      ShellRoute(
        navigatorKey: _principalShellKey,
        builder: (context, state, child) => PrincipalShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.principalDashboard,
            builder: (c, s) => const PrincipalDashboardScreen(),
            routes: [
              GoRoute(
                path: 'analytics',
                builder: (c, s) => const SchoolAnalyticsScreen(),
              ),
              GoRoute(
                path: 'student-progress',
                builder: (c, s) => const StudentProgressScreen(),
              ),
              GoRoute(
                path: 'proof-approval',
                builder: (c, s) => const ProofApprovalScreen(),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (c, s) => ProofPreviewScreen(
                      orderId: s.pathParameters['orderId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'order-progress',
                builder: (c, s) => const OrderProgressScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.principalData,
            builder: (c, s) => const PrincipalDataScreen(),
          ),
          GoRoute(
            path: AppRoutes.principalAttendance,
            builder: (c, s) => const PrincipalAttendanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.principalProfile,
            builder: (c, s) => const PrincipalProfileScreen(),
            routes: [
              GoRoute(
                  path: 'edit', builder: (c, s) => const EditProfileScreen()),
              GoRoute(
                path: 'settings',
                builder: (c, s) => const SettingsScreen(),
                routes: [
                  GoRoute(
                      path: 'theme',
                      builder: (c, s) => const ThemeSettingsScreen()),
                  GoRoute(
                      path: 'notifications',
                      builder: (c, s) => const NotificationSettingsScreen()),
                ],
              ),
              GoRoute(
                  path: 'help', builder: (c, s) => const HelpSupportScreen()),
              GoRoute(path: 'faq', builder: (c, s) => const FaqScreen()),
              GoRoute(path: 'about', builder: (c, s) => const AboutScreen()),
            ],
          ),
        ],
      ),

      // ── Vendor Shell ──────────────────────────────────────────
      ShellRoute(
        navigatorKey: _vendorShellKey,
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          // Home
          GoRoute(
            path: AppRoutes.vendorDashboard,
            builder: (c, s) => const VendorDashboardScreen(),
          ),
          // Clients
          GoRoute(
            path: '/vendor/clients',
            builder: (c, s) => const ClientListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (c, s) => const AddClientScreen(),
              ),
              GoRoute(
                path: ':clientId',
                builder: (c, s) => ClientDetailsScreen(
                  clientId: s.pathParameters['clientId']!,
                ),
              ),
            ],
          ),
          // Order creation (flat path matching vendor_screens navigation)
          GoRoute(
            path: '/vendor/orders/create',
            builder: (c, s) => CreateOrderScreen(
              preselectedClient: s.extra as Map<String, dynamic>?,
            ),
          ),
          // Project board
          GoRoute(
            path: '/vendor/project-board',
            builder: (c, s) => const ProjectBoardScreen(),
            routes: [
              GoRoute(
                path: ':stage',
                builder: (c, s) => WorkflowStageDetailScreen(
                  stage: s.pathParameters['stage']!,
                ),
              ),
            ],
          ),
          // Order Details Screen - FIXED: Using extra parameter (safer, no URL encoding)
          GoRoute(
            path: '/order-details',
            builder: (c, s) {
              final order = s.extra as Map<String, dynamic>?;
              if (order == null) {
                return const Scaffold(
                  body: Center(
                    child: Text('Order data not found'),
                  ),
                );
              }
              return OrderDetailsScreen(order: order);
            },
          ),
          // Upload flows (flat paths used by vendor_screens.dart)
          GoRoute(
              path: '/vendor/upload-excel',
              builder: (c, s) => const UploadExcelScreen()),
          GoRoute(
              path: '/vendor/column-mapping',
              // ColumnMappingScreen requires file headers — reached via Navigator.push from UploadExcelScreen
              builder: (c, s) => const UploadExcelScreen()),
          GoRoute(
              path: '/vendor/upload-photos',
              builder: (c, s) => const UploadPhotosScreen()),
          GoRoute(
              path: '/vendor/bulk-photo-matching',
              builder: (c, s) => const BulkPhotoMatchingScreen()),
          // Notifications
          GoRoute(
            path: AppRoutes.vendorNotifications,
            builder: (c, s) => const NotificationCenterScreen(),
            routes: [
              GoRoute(
                  path: 'feed', builder: (c, s) => const ActivityFeedScreen()),
              GoRoute(
                  path: ':notifId',
                  builder: (c, s) => const NotificationDetailScreen()),
            ],
          ),
          // Profile
          GoRoute(
            path: AppRoutes.vendorProfile,
            builder: (c, s) => const VendorProfileScreen(),
            routes: [
              GoRoute(
                  path: 'edit', builder: (c, s) => const EditProfileScreen()),
              GoRoute(
                path: 'settings',
                builder: (c, s) => const SettingsScreen(),
                routes: [
                  GoRoute(
                      path: 'theme',
                      builder: (c, s) => const ThemeSettingsScreen()),
                  GoRoute(
                      path: 'notifications',
                      builder: (c, s) => const NotificationSettingsScreen()),
                ],
              ),
              GoRoute(
                  path: 'help', builder: (c, s) => const HelpSupportScreen()),
              GoRoute(path: 'faq', builder: (c, s) => const FaqScreen()),
              GoRoute(path: 'about', builder: (c, s) => const AboutScreen()),
            ],
          ),
        ],
      ),
    ],
  );

  static CustomTransitionPage<void> _buildPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';

  static const studentDashboard = '/student';
  static const studentNotifications = '/student/notifications';
  static const studentProfile = '/student/profile';

  static const teacherDashboard = '/teacher';
  static const teacherData = '/teacher/data';
  static const teacherAttendance = '/teacher/attendance';
  static const teacherProfile = '/teacher/profile';

  static const principalDashboard = '/principal';
  static const principalData = '/principal/data';
  static const principalAttendance = '/principal/attendance';
  static const principalProfile = '/principal/profile';

  static const vendorDashboard = '/vendor';
  static const vendorNotifications = '/vendor/notifications';
  static const vendorProfile = '/vendor/profile';

  /// Legacy alias kept so that any remaining references to '/profile' are
  /// caught by the router's redirect guard and forwarded to the correct
  /// role-specific profile screen.
  static const profile = '/profile';
}
