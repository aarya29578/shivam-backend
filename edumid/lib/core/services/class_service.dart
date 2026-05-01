import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_config.dart';

class ClassService {
  ClassService._();
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Check if a class exists for [schoolId] (or [principalId]) and create it if missing.
  /// Returns the parsed JSON response from the backend.
  static Future<Map<String, dynamic>> checkOrCreateClass({
    String? schoolId,
    String? principalId,
    required String className,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('No internet connection');
    }

    try {
      final payload = <String, dynamic>{'className': className.trim()};
      if (schoolId != null && schoolId.isNotEmpty)
        payload['schoolId'] = schoolId;
      if (principalId != null && principalId.isNotEmpty)
        payload['principalId'] = principalId;

      final resp = await _dio.post('/api/class/check-or-create', data: payload);
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
      throw Exception('Server error');
    } on DioException catch (e) {
      if (e.response == null) {
        throw Exception(
            'Unable to reach server. Please check API URL or internet connection.');
      }
      throw Exception('Server error');
    }
  }
}
