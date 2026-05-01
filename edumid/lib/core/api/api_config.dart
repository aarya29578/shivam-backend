/// Global API Configuration
/// This file centralizes all backend API settings to ensure consistency
/// across all modules (Vendor, Principal, Teacher).

class ApiConfig {
  // ── Backend Server ────────────────────────────────────────────────
  /// Backend server address.
  /// Override at build time with:
  /// --dart-define=API_BASE_URL=https://your-domain.example
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://72.62.241.170:5001',
  );

  // ── API Endpoints ─────────────────────────────────────────────────

  /// Vendor endpoints
  static const String vendorClients = '$baseUrl/api/vendor/clients';
  static const String vendorOrders = '$baseUrl/api/vendor/orders';
  static const String vendorDashboard = '$baseUrl/api/vendor/dashboard';
  static const String vendorProducts = '$baseUrl/api/vendor/products';

  /// Principal endpoints (shared with Teacher module - read-only)
  static const String principalClasses = '$baseUrl/api/principal/classes';
  static const String principalMembers = '$baseUrl/api/principal/members';
  static const String principalDashboard = '$baseUrl/api/principal/dashboard';
  static const String principalIdCardForm =
      '$baseUrl/api/principal/id-card-form';
  static const String principalPromoteClass =
      '$baseUrl/api/principal/promote-class';
  static const String principalPurchaseOrders =
      '$baseUrl/api/principal/purchase-orders';

  /// Form endpoints (role-based)
  static const String formGet = '$baseUrl/api/form';
  static const String formSubmit = '$baseUrl/api/form/submit';
  static const String formSubmissions = '$baseUrl/api/form/submissions';

  /// Teacher endpoints (note: Teacher uses Principal's endpoints since no separate teacher routes exist in backend)
  static const String teacherClasses = '$baseUrl/api/principal/classes';
  static const String teacherAttendance = '$baseUrl/api/principal/members';
  static const String teacherDashboard = '$baseUrl/api/principal/classes';

  /// Notice endpoints
  static const String noticesBase = '$baseUrl/api/notices';

  /// Quick Capture (vendor) endpoints
  static const String quickPhotoUpload = '$baseUrl/api/upload/quick-photo';
  static const String quickPhotos = '$baseUrl/api/upload/quick-photos';
  static const String vendorSchools = '$baseUrl/api/vendor/schools';

  /// Returns class names for a school: GET vendorSchoolClasses(clientId)
  static String vendorSchoolClasses(String clientId) =>
      '$baseUrl/api/vendor/clients/$clientId/school-classes';

  /// Student endpoints
  static const String studentUploadPhoto = '$baseUrl/api/students/upload-photo';

  /// Returns students for a school: GET studentList(clientId, className)
  static String studentList(String clientId, {String? className}) {
    final base = '$baseUrl/api/students?schoolId=$clientId';
    return className != null && className.isNotEmpty
        ? '$base&className=${Uri.encodeComponent(className)}'
        : base;
  }

  /// Returns school members filtered by type and optional class:
  ///   GET vendorSchoolMembers(clientId, type: 'student', className: 'X')
  static String vendorSchoolMembers(String clientId, {String? type, String? className}) {
    var url = '$baseUrl/api/vendor/clients/$clientId/school-members';
    final params = <String>[];
    if (type != null && type.isNotEmpty) params.add('type=${Uri.encodeComponent(type)}');
    if (className != null && className.isNotEmpty) params.add('className=${Uri.encodeComponent(className)}');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    return url;
  }

  /// Generic image upload endpoints
  static const String uploadImage = '$baseUrl/api/upload/image';
  static const String uploadImages = '$baseUrl/api/upload/images';

  /// Auth endpoints
  static const String authRegister = '$baseUrl/api/auth/register';
  static const String authLogin = '$baseUrl/api/auth/login';
  static const String authLogout = '$baseUrl/api/auth/logout';
  static const String authProfile = '$baseUrl/api/auth/profile';
  static const String authUpdateProfile = '$baseUrl/api/auth/update-profile';

  // ── HTTP Configuration ────────────────────────────────────────────

  /// Default connection timeout in seconds
  static const int connectionTimeout = 15;

  /// Default receive timeout in seconds
  static const int receiveTimeout = 15;

  // ── Helper Methods ────────────────────────────────────────────────

  /// Get full endpoint URL with parameters
  /// Example: ApiConfig.endpoint('/api/vendor/clients', queryParams: {'vendorId': 'vendor_001'})
  static String endpoint(
    String path, {
    Map<String, String>? queryParams,
  }) {
    String url = '$baseUrl$path';
    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$query';
    }
    return url;
  }

  /// Rewrites a stored image URL so the host matches [baseUrl].
  ///
  /// During development the backend stores URLs with the host that received
  /// the upload request (e.g. `localhost:5001` via adb reverse).  In
  /// production the host is the public IP / domain.  Either way, this helper
  /// ensures the displayed URL always uses the [baseUrl] the app was compiled
  /// with, so images load correctly in every environment.
  ///
  /// Relative paths (starting with `/`) are prefixed with [baseUrl].
  static String resolveImageUrl(String storedUrl) {
    if (storedUrl.isEmpty) return storedUrl;
    if (storedUrl.startsWith('/')) return '$baseUrl$storedUrl';
    try {
      final stored = Uri.parse(storedUrl);
      final base = Uri.parse(baseUrl);
      // Already matches — nothing to do
      if (stored.host == base.host && stored.port == base.port &&
          stored.scheme == base.scheme) {
        return storedUrl;
      }
      return stored
          .replace(scheme: base.scheme, host: base.host, port: base.port)
          .toString();
    } catch (_) {
      return storedUrl;
    }
  }

  // ── Debug Support ─────────────────────────────────────────────────

  /// Print API configuration (useful for debugging)
  static void debugPrint() {
    print('╔════════════════════════════════════════╗');
    print('║   API Configuration                    ║');
    print('╚════════════════════════════════════════╝');
    print('Base URL:         $baseUrl');
    print('Vendor Classes:   $vendorClients');
    print('Principal Classes: $principalClasses');
    print('Teacher Classes:  $teacherClasses');
    print('Connection Timeout: ${connectionTimeout}s');
    print('Receive Timeout:  ${receiveTimeout}s');
    print('');
  }
}
