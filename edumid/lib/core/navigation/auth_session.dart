import '../constants/app_constants.dart';

/// Lightweight in-memory session that the router's redirect guard uses.
///
/// Call [setRole] immediately after a successful login / role selection so that
/// all subsequent route-guard checks know the authenticated role.
/// Call [clear] on logout to wipe the role and force a redirect to /login.
abstract class AuthSession {
  static UserRole? _role;

  static UserRole? get role => _role;

  /// Persist the authenticated role for the lifetime of the app session.
  static void setRole(UserRole role) => _role = role;

  static void setRoleFromString(String role) {
    switch (role.toLowerCase().trim()) {
      case 'student':
        _role = UserRole.student;
        break;
      case 'teacher':
        _role = UserRole.teacher;
        break;
      case 'principal':
        _role = UserRole.principal;
        break;
      case 'vendor':
        _role = UserRole.vendor;
        break;
      default:
        _role = null;
    }
  }

  /// Infer the role from the current path.
  /// Used as a fallback when [_role] is null (e.g. after hot-restart during
  /// development, or when [SessionRestoreScreen] navigates directly to a
  /// role path without calling [setRole] first).
  static void inferFromPath(String path) {
    if (_role != null) return;
    if (path.startsWith('/student'))
      _role = UserRole.student;
    else if (path.startsWith('/teacher'))
      _role = UserRole.teacher;
    else if (path.startsWith('/principal'))
      _role = UserRole.principal;
    else if (path.startsWith('/vendor')) _role = UserRole.vendor;
  }

  /// Clear the authenticated role.  Call this on logout.
  static void clear() => _role = null;

  /// The root path for the currently authenticated role.
  static String get rootPath => switch (_role) {
        UserRole.student => '/student',
        UserRole.teacher => '/teacher',
        UserRole.principal => '/principal',
        UserRole.vendor => '/vendor',
        null => '/login',
      };
}
