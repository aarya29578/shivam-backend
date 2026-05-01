import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_config.dart';
import '../constants/app_constants.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Dio _dio({String? token}) => Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: ApiConfig.connectionTimeout),
          receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

  // ── REGISTER ───────────────────────────────────────────────────────
  Future<String?> register({
    required String name,
    required String phone,
    required String password,
    String? schoolCode,
    String? vendorCode,
    required String role,
    String schoolName = '',
  }) async {
    final body = {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      if (role != 'vendor') 'schoolCode': (schoolCode ?? '').trim(),
      if (role == 'vendor') 'vendorCode': (vendorCode ?? '').trim(),
      if (schoolName.isNotEmpty) 'schoolName': schoolName,
    };
    print('[AuthService.register] body: $body');

    try {
      final response = await _dio().post(ApiConfig.authRegister, data: body);
      if (response.statusCode == 201 || response.statusCode == 200) return null;
      return _extractMessage(response.data, 'Registration failed');
    } on DioException catch (e) {
      if (e.response == null) {
        return 'Unable to reach server. Please check internet/API URL.';
      }
      return _extractMessage(e.response?.data, 'Registration failed');
    } catch (_) {
      return 'Registration failed';
    }
  }

  // ── LOGIN ──────────────────────────────────────────────────────────
  Future<String?> login({
    required String phone,
    required String password,
    String? schoolCode,
    String? vendorCode,
    required String role,
  }) async {
    try {
      print('[AuthService.login] URL: ${ApiConfig.authLogin}');
      final response = await _dio().post(
        ApiConfig.authLogin,
        data: {
          'phone': phone,
          'password': password,
          'role': role,
          if (role != 'vendor') 'schoolCode': (schoolCode ?? '').trim(),
          if (role == 'vendor') 'vendorCode': (vendorCode ?? '').trim(),
        },
      );

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final token = (data['token'] ?? '').toString();
        final user = Map<String, dynamic>.from(data['user'] ?? {});

        if (token.isEmpty || user.isEmpty) return 'Invalid login response';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyAccessToken, token);
        await prefs.setString(AppConstants.keyUserData, jsonEncode(user));
        await prefs.setString(
            AppConstants.keySelectedRole, (user['role'] ?? '').toString());
        return null;
      }

      return _extractMessage(response.data, 'Login failed');
    } on DioException catch (e) {
      if (e.response == null) {
        return 'Unable to reach server. Please check internet/API URL.';
      }
      return _extractMessage(e.response?.data, 'Login failed');
    } catch (_) {
      return 'Login failed';
    }
  }

  // ── GET PROFILE (from backend — always fresh) ──────────────────────
  Future<Map<String, dynamic>?> getProfile() async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _dio(token: token).get(ApiConfig.authProfile);
      if (response.statusCode == 200 && response.data is Map) {
        final user = Map<String, dynamic>.from(
            (response.data as Map)['user'] ?? response.data);
        // Keep local storage in sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyUserData, jsonEncode(user));
        return user;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── UPDATE PROFILE ─────────────────────────────────────────────────
  /// Returns null on success, error string on failure.
  Future<String?> updateProfile({
    String? name,
    String? phone,
  }) async {
    final token = await getStoredToken();
    if (token == null || token.isEmpty) return 'Not authenticated';

    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;

    try {
      final response = await _dio(token: token).put(
        ApiConfig.authUpdateProfile,
        data: body,
      );
      if (response.statusCode == 200 && response.data is Map) {
        final user = Map<String, dynamic>.from(
            (response.data as Map)['user'] ?? response.data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyUserData, jsonEncode(user));
        return null;
      }
      return _extractMessage(response.data, 'Update failed');
    } on DioException catch (e) {
      return _extractMessage(e.response?.data, 'Update failed');
    } catch (_) {
      return 'Update failed';
    }
  }

  // ── STORED USER (cached from last login/profile fetch) ─────────────
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyUserData);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyAccessToken);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAccessToken);
    await prefs.remove(AppConstants.keyUserData);
    await prefs.remove(AppConstants.keySelectedRole);
    await prefs.remove('principal_id_cache'); // clear principal data cache
  }

  // ── Helper ─────────────────────────────────────────────────────────
  String _extractMessage(dynamic data, String fallback) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null) return msg.toString();
    }
    return fallback;
  }
}
