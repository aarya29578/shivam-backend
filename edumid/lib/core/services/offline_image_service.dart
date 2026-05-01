import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/captured_image_record.dart';

/// Handles saving captured photos to the local filesystem and
/// writing lightweight metadata (no image bytes) to Hive.
///
/// Naming convention: {schoolCode}_{className}_{roll}.jpg
class OfflineImageService {
  static final OfflineImageService instance = OfflineImageService._();
  OfflineImageService._();

  static const String _boxName = 'captured_images';

  /// Call once from main() AFTER Hive.initFlutter() + openBox().
  Future<void> init() async {
    // Ensure the persistent photos directory exists.
    await _captureDir();
  }

  // ── Public API ──────────────────────────────────────────────────

  /// Copies the camera temp file to the app's documents directory with
  /// the canonical filename, then persists metadata in Hive.
  /// Returns the Hive record key for the saved entry.
  Future<String> saveCapture({
    required String imagePath,
    required String schoolId,
    required String schoolCode,
    required String className,
    required String rollNo,
    String studentId = '',
    String studentName = '',
  }) async {
    // 1. Build permanent path
    final dir = await _captureDir();
    final fileName = '${schoolCode}_${className}_$rollNo.jpg';
    final destPath = '${dir.path}/$fileName';

    // 2. Copy from camera temp → permanent location
    await File(imagePath).copy(destPath);

    // 3. Write metadata to Hive (NO image bytes)
    final record = CapturedImageRecord(
      filePath: destPath,
      schoolId: schoolId,
      schoolCode: schoolCode,
      className: className,
      rollNo: rollNo,
      studentId: studentId,
      studentName: studentName,
      uploaded: false,
      capturedAt: DateTime.now(),
    );

    final key = '${DateTime.now().millisecondsSinceEpoch}_$rollNo';
    final box = Hive.box(_boxName);
    await box.put(key, record.toMap());

    return key;
  }

  /// Returns all records currently stored.
  List<MapEntry<dynamic, CapturedImageRecord>> allRecords() {
    final box = Hive.box(_boxName);
    return box.toMap().entries.map((e) {
      return MapEntry(
        e.key,
        CapturedImageRecord.fromMap(e.value as Map),
      );
    }).toList()
      ..sort((a, b) => a.value.capturedAt.compareTo(b.value.capturedAt));
  }

  /// Number of photos not yet confirmed uploaded.
  int get pendingCount {
    final box = Hive.box(_boxName);
    return box.values
        .where((v) =>
            !(CapturedImageRecord.fromMap(v as Map).uploaded))
        .length;
  }

  /// Mark a record as successfully uploaded and store the server URL.
  Future<void> markUploaded(dynamic key, String serverUrl) async {
    final box = Hive.box(_boxName);
    final raw = box.get(key);
    if (raw == null) return;
    final record = CapturedImageRecord.fromMap(raw as Map);
    await box.put(key, record.copyWith(uploaded: true, serverUrl: serverUrl).toMap());
  }

  // ── Private helpers ─────────────────────────────────────────────

  Future<Directory> _captureDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/quick_captures');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
