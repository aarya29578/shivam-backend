abstract class AppConstants {
  static const String appName = 'EDUMID';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Smart ID & Certificate Platform';

  // API
  static const String baseUrl = 'https://api.edumid.in/v1';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData = 'user_data';
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboarded = 'onboarded';
  static const String keySelectedRole = 'selected_role';

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animVerySlow = Duration(milliseconds: 800);

  // Pagination
  static const int pageSize = 20;

  // File Limits
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxExcelSizeBytes = 20 * 1024 * 1024; // 20 MB
  static const int maxPdfSizeBytes = 50 * 1024 * 1024; // 50 MB

  // OTP
  static const int otpLength = 6;
  static const int otpExpirySeconds = 120;
}

/// App-level user roles
enum UserRole {
  student,
  teacher,
  principal,
  vendor;

  String get displayName => switch (this) {
        UserRole.student => 'Student',
        UserRole.teacher => 'Teacher',
        UserRole.principal => 'Principal',
        UserRole.vendor => 'Vendor',
      };

  String get iconName => switch (this) {
        UserRole.student => 'student',
        UserRole.teacher => 'teacher',
        UserRole.principal => 'principal',
        UserRole.vendor => 'vendor',
      };
}

/// Order workflow stages
enum OrderStage {
  draft,
  dataUploaded,
  designing,
  proofSent,
  approved,
  printing,
  dispatched,
  delivered;

  String get displayName => switch (this) {
        OrderStage.draft => 'Draft',
        OrderStage.dataUploaded => 'Data Uploaded',
        OrderStage.designing => 'Designing',
        OrderStage.proofSent => 'Proof Sent',
        OrderStage.approved => 'Approved',
        OrderStage.printing => 'Printing',
        OrderStage.dispatched => 'Dispatched',
        OrderStage.delivered => 'Delivered',
      };

  int get stepIndex => switch (this) {
        OrderStage.draft => 0,
        OrderStage.dataUploaded => 1,
        OrderStage.designing => 2,
        OrderStage.proofSent => 3,
        OrderStage.approved => 4,
        OrderStage.printing => 5,
        OrderStage.dispatched => 6,
        OrderStage.delivered => 7,
      };
}
