import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_config.dart';
import '../models/captured_image_record.dart';
import '../services/auth_service.dart';
import '../services/offline_image_service.dart';

/// Watches connectivity and drains the Hive upload queue.
///
/// Design goals:
///  • Retry-safe: failed uploads keep `uploaded = false` and are retried.
///  • No data loss: the queue survives app restarts via Hive persistence.
///  • Non-blocking: uploads run in the background; UI notifiers update after each item.
class UploadQueueService {
  static final UploadQueueService instance = UploadQueueService._();
  UploadQueueService._();

  // Observables for reactive UI
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<bool> isUploading = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _draining = false;

  // ── Lifecycle ────────────────────────────────────────────────────

  Future<void> init() async {
    _refreshPendingCount();

    // Auto-upload whenever network becomes available.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) tryUploadPendingImages();
    });

    // Also try immediately on startup (in case we're already online).
    tryUploadPendingImages();
  }

  void dispose() {
    _connectivitySub?.cancel();
    pendingCount.dispose();
    isUploading.dispose();
    lastError.dispose();
  }

  // ── Public trigger ───────────────────────────────────────────────

  /// Manually trigger the upload queue drain.
  /// Safe to call multiple times — debounced by [_draining] guard.
  Future<void> tryUploadPendingImages() async {
    if (_draining) return;
    _draining = true;
    isUploading.value = true;
    try {
      await _drain();
    } finally {
      _draining = false;
      isUploading.value = false;
      _refreshPendingCount();
    }
  }

  // ── Queue processor ──────────────────────────────────────────────

  Future<void> _drain() async {
    // Guard: skip if offline
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return;

    final records = OfflineImageService.instance.allRecords();

    for (final entry in records) {
      if (entry.value.uploaded) continue;

      final record = entry.value;
      final key = entry.key;

      // Skip if the file no longer exists on disk (edge case: storage cleared)
      if (!File(record.filePath).existsSync()) {
        debugPrint('[UploadQueue] File missing, skipping key=$key');
        continue;
      }

      try {
        final serverUrl = await _uploadSingle(record);
        await OfflineImageService.instance.markUploaded(key, serverUrl);
        lastError.value = null;
        _refreshPendingCount();
        debugPrint('[UploadQueue] ✓ Uploaded roll ${record.rollNo}');
      } catch (e) {
        // Keep uploaded=false → will retry next time.
        lastError.value = 'Upload failed for roll ${record.rollNo}: $e';
        debugPrint('[UploadQueue] ✗ Roll ${record.rollNo}: $e');
      }
    }
  }

  Future<String> _uploadSingle(CapturedImageRecord record) async {
    final token = await AuthService.instance.getStoredToken();
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final fileName =
        '${record.schoolCode}_${record.className}_${record.rollNo}.jpg';

    // Student-driven capture: use profile-photo endpoint if studentId is known
    if (record.studentId.isNotEmpty) {
      final uploadUrl =
          '${ApiConfig.baseUrl}/api/students/upload-profile-photo';
      // ignore: avoid_print
      print('UPLOAD URL: $uploadUrl');
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          record.filePath,
          filename: fileName,
        ),
        'studentId': record.studentId,
      });
      final response = await dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      final data = response.data;
      if (data is Map) {
        final url = (data['url'] ?? data['imageUrl'] ?? data['filePath'] ?? '')
            .toString();
        debugPrint('[UploadQueue] ✓ profile-photo uploaded: $url');
        return url;
      }
      return '';
    }

    // Legacy roll-based capture
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        record.filePath,
        filename: fileName,
      ),
      'schoolId': record.schoolId,
      'schoolCode': record.schoolCode,
      'className': record.className,
      'rollNo': record.rollNo,
    });

    final response = await dio.post(
      ApiConfig.studentUploadPhoto,
      data: formData,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    // Extract server URL from response if available
    final data = response.data;
    if (data is Map) {
      return (data['url'] ?? data['imageUrl'] ?? data['filePath'] ?? '')
          .toString();
    }
    return '';
  }

  // ── Internal helpers ─────────────────────────────────────────────

  void _refreshPendingCount() {
    pendingCount.value = OfflineImageService.instance.pendingCount;
  }
}
