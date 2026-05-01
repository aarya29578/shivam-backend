import 'package:dio/dio.dart';
import '../api/api_config.dart';

/// Model class for form field
class IdCardFormField {
  final String fieldId;
  final String fieldName;
  final String fieldType; // 'text', 'dropdown', 'number', 'date'
  final bool isRequired;
  final int order;

  IdCardFormField({
    required this.fieldId,
    required this.fieldName,
    required this.fieldType,
    this.isRequired = true,
    required this.order,
  });

  // Serialize to backend expected shape: label/type/required/order
  Map<String, dynamic> toJson() => {
        'label': fieldName,
        'type': fieldType,
        'required': isRequired,
        'order': order,
      };

  factory IdCardFormField.fromJson(Map<String, dynamic> json, int index) {
    final label =
        json['label'] ?? json['fieldName'] ?? json['field_name'] ?? '';
    final type = json['type'] ?? json['fieldType'] ?? 'text';
    final required = json['required'] ?? json['isRequired'] ?? true;
    final fieldId = json['fieldId'] ??
        'f_${label.toString().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), '_')}_$index';

    return IdCardFormField(
      fieldId: fieldId,
      fieldName: label ?? '',
      fieldType: type ?? 'text',
      isRequired: required ?? true,
      order: json['order'] ?? index,
    );
  }
}

/// Model class for ID Card Form
class IdCardForm {
  final String id;
  final String principalId;
  final String formTitle;
  final String formDescription;
  final DateTime? updatedAt;
  final List<IdCardFormField> formFields;

  IdCardForm({
    required this.id,
    required this.principalId,
    required this.formTitle,
    required this.formDescription,
    this.updatedAt,
    required this.formFields,
  });

  Map<String, dynamic> toJson() => {
        'principalId': principalId,
        'formTitle': formTitle,
        'formDescription': formDescription,
        'updatedAt': updatedAt?.toIso8601String(),
        'formFields': formFields.map((f) => f.toJson()).toList(),
      };

  factory IdCardForm.fromJson(Map<String, dynamic> json) => IdCardForm(
        id: json['id'] ?? json['_id'] ?? '',
        principalId: json['principalId'] ?? '',
        formTitle: json['formTitle'] ?? 'ID Card Form',
        formDescription: json['formDescription'] ?? '',
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
        formFields: List<IdCardFormField>.from((json['formFields'] ?? [])
            .asMap()
            .entries
            .map((e) => IdCardFormField.fromJson(e.value, e.key))),
      );
}

/// ID Card Form Service
class IdCardFormService {
  static final IdCardFormService _instance = IdCardFormService._internal();

  factory IdCardFormService() {
    return _instance;
  }

  IdCardFormService._internal();

  late Dio _dio;

  static const List<String> _knownBaseUrls = [
    ApiConfig.baseUrl,
  ];

  /// Initialize Dio with proper configuration
  Dio _getFormDio() {
    return Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: ApiConfig.connectionTimeout),
      receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
      validateStatus: (status) => status != null && status < 500,
    ));
  }

  List<String> _candidateBaseUrls() {
    final seen = <String>{};
    final urls = <String>[];
    for (final url in _knownBaseUrls) {
      final clean = url.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean)) {
        urls.add(clean);
      }
    }
    return urls;
  }

  Future<Response<dynamic>> _postWithFallback(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastError;
    for (final base in _candidateBaseUrls()) {
      final url = '$base$path';
      try {
        final response = await _dio.post(
          url,
          data: data,
          queryParameters: queryParameters,
        );
        if (response.statusCode != null && response.statusCode! < 500) {
          if (base != ApiConfig.baseUrl) {
            print('[IdCardFormService] Using fallback base URL: $base');
          }
          return response;
        }
      } on DioException catch (e) {
        lastError = e;
        print('[IdCardFormService] POST failed on $url: $e');
      }
    }
    throw lastError ?? Exception('All POST endpoints failed for $path');
  }

  Future<Response<dynamic>> _getWithFallback(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastError;
    for (final base in _candidateBaseUrls()) {
      final url = '$base$path';
      try {
        final response = await _dio.get(
          url,
          queryParameters: queryParameters,
        );
        if (response.statusCode != null && response.statusCode! < 500) {
          if (base != ApiConfig.baseUrl) {
            print('[IdCardFormService] Using fallback base URL: $base');
          }
          return response;
        }
      } on DioException catch (e) {
        lastError = e;
        print('[IdCardFormService] GET failed on $url: $e');
      }
    }
    throw lastError ?? Exception('All GET endpoints failed for $path');
  }

  /// Save ID Card Form (Principal only)
  ///
  /// Sends form fields to backend to save/update the ID card form
  /// Returns the saved form ID if successful
  Future<String?> saveIdCardForm({
    required String principalId,
    required List<IdCardFormField> formFields,
    required String formTitle,
    String formDescription = '',
  }) async {
    try {
      _dio = _getFormDio();

      final payload = {
        'principalId': principalId,
        'formTitle': formTitle,
        'formDescription': formDescription,
        'formFields': formFields.map((f) => f.toJson()).toList(),
      };

      print('[IdCardFormService] Saving form for principal: $principalId');
      print('[IdCardFormService] Fields count: ${formFields.length}');

      final response = await _postWithFallback(
        '/api/principal/id-card-form',
        data: payload,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final formId = data['form']?['id'] ?? data['id'] ?? '';
        print('[IdCardFormService] ✅ Form saved successfully. ID: $formId');
        return formId;
      } else {
        print(
            '[IdCardFormService] ❌ Failed to save form. Status: ${response.statusCode}');
        print('[IdCardFormService] Response: ${response.data}');
        return null;
      }
    } catch (err) {
      print('[IdCardFormService] ❌ Error saving form: $err');
      return null;
    }
  }

  /// Fetch ID Card Form (for all roles to fill)
  ///
  /// Retrieves the form for a specific principal via the public /api/form endpoint
  /// Returns null if no form found or error occurred
  Future<IdCardForm?> getIdCardForm({
    required String principalId,
  }) async {
    try {
      _dio = _getFormDio();

      print('[IdCardFormService] Fetching form for principal: $principalId');

      final response = await _getWithFallback(
        '/api/form',
        queryParameters: {'principalId': principalId},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;

        // Default fields that must always appear
        final defaultFields = [
          {'label': 'Full Name', 'type': 'text', 'required': true},
          {'label': 'Class & Section', 'type': 'text', 'required': true},
          {'label': 'Roll Number', 'type': 'text', 'required': true},
          {'label': 'Blood Group', 'type': 'text', 'required': true},
          {'label': 'Mobile Number', 'type': 'text', 'required': true},
        ];

        final serverFields =
            List<Map<String, dynamic>>.from(data?['formFields'] ?? []);
        final combined = [...defaultFields, ...serverFields];

        final mergedJson = {
          'id': data?['id'] ?? data?['_id'] ?? '',
          'principalId': principalId,
          'formTitle': data?['formTitle'] ?? 'ID Card Form',
          'formDescription': data?['formDescription'] ?? '',
          'updatedAt': data?['updatedAt'],
          'formFields': combined,
        };

        final form = IdCardForm.fromJson(mergedJson);
        print('[IdCardFormService] ✅ Form fetched successfully');
        print('[IdCardFormService] Fields: ${form.formFields.length}');
        return form;
      } else {
        print('[IdCardFormService] ℹ️  No form found for principal');
        return null;
      }
    } catch (err) {
      print('[IdCardFormService] ❌ Error fetching form: $err');
      return null;
    }
  }

  /// Submit Form Data (Student/Teacher)
  ///
  /// Students and teachers submit filled form data
  /// Returns submission ID if successful
  Future<String?> submitForm({
    required String principalId,
    required String userId,
    required String userEmail,
    required String userName,
    required String role, // 'student' or 'teacher'
    required Map<String, String> formData,
  }) async {
    try {
      _dio = _getFormDio();

      final payload = {
        'principalId': principalId,
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'role': role,
        'formData': formData,
      };

      print('[IdCardFormService] Submitting form for user: $userId ($role)');
      print('[IdCardFormService] Fields submitted: ${formData.length}');

      final response = await _postWithFallback(
        '/api/form/submit',
        data: payload,
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final submissionId = data['submission']?['id'] ?? '';
        print(
            '[IdCardFormService] ✅ Form submitted successfully. ID: $submissionId');
        return submissionId;
      } else {
        print(
            '[IdCardFormService] ❌ Failed to submit form. Status: ${response.statusCode}');
        print('[IdCardFormService] Response: ${response.data}');
        return null;
      }
    } catch (err) {
      print('[IdCardFormService] ❌ Error submitting form: $err');
      return null;
    }
  }

  /// Get Form Submissions (Principal only)
  ///
  /// Fetch all form submissions for a principal
  /// Optionally filter by role ('student', 'teacher', 'all')
  Future<List<Map<String, dynamic>>> getFormSubmissions({
    required String principalId,
    String role = 'all',
  }) async {
    try {
      _dio = _getFormDio();

      print(
          '[IdCardFormService] Fetching submissions for principal: $principalId');

      final query = {'principalId': principalId};
      if (role != 'all') {
        query['role'] = role;
      }

      final response = await _getWithFallback(
        '/api/form/submissions',
        queryParameters: query,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final submissions =
            List<Map<String, dynamic>>.from(data['submissions'] ?? []);
        print(
            '[IdCardFormService] ✅ Fetched ${submissions.length} submissions');
        return submissions;
      } else {
        print(
            '[IdCardFormService] ❌ Failed to fetch submissions. Status: ${response.statusCode}');
        print('[IdCardFormService] Response: ${response.data}');
        return [];
      }
    } catch (err) {
      print('[IdCardFormService] ❌ Error fetching submissions: $err');
      return [];
    }
  }

  /// Get User's Own Submissions (Student/Teacher)
  ///
  /// Fetch submissions for the current user (student or teacher)
  /// Returns only submissions made by this specific user
  Future<List<Map<String, dynamic>>> getUserSubmissions({
    required String principalId,
    required String userId,
  }) async {
    try {
      _dio = _getFormDio();

      print('[IdCardFormService] Fetching submissions for user: $userId');

      final response = await _getWithFallback(
        '/api/form/submissions',
        queryParameters: {
          'principalId': principalId,
          'userId': userId, // Filter by user
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final submissions =
            List<Map<String, dynamic>>.from(data['submissions'] ?? []);
        print(
            '[IdCardFormService] ✅ Fetched ${submissions.length} user submissions');
        return submissions;
      } else {
        print(
            '[IdCardFormService] ⚠️  No submissions found. Status: ${response.statusCode}');
        return [];
      }
    } catch (err) {
      print('[IdCardFormService] ❌ Error fetching user submissions: $err');
      return [];
    }
  }

  /// Get Student Submissions (for Teachers)
  ///
  /// Fetch all student submissions for the principal
  /// Used by teachers to view student forms
  Future<List<Map<String, dynamic>>> getStudentSubmissions({
    required String principalId,
  }) async {
    try {
      _dio = _getFormDio();

      print(
          '[IdCardFormService] Fetching all student submissions for principal: $principalId');

      final response = await _getWithFallback(
        '/api/form/submissions',
        queryParameters: {
          'principalId': principalId,
          'role': 'student', // Only student submissions
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final submissions =
            List<Map<String, dynamic>>.from(data['submissions'] ?? []);
        print(
            '[IdCardFormService] ✅ Fetched ${submissions.length} student submissions');
        return submissions;
      } else {
        print(
            '[IdCardFormService] ⚠️  No student submissions found. Status: ${response.statusCode}');
        return [];
      }
    } catch (err) {
      print('[IdCardFormService] ❌ Error fetching student submissions: $err');
      return [];
    }
  }
}
