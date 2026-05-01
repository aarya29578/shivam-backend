/// Metadata stored in Hive for every captured Quick-Capture photo.
/// Image BYTES are never stored in Hive — only the local filepath.
class CapturedImageRecord {
  final String filePath;
  final String schoolId;
  final String schoolCode;
  final String className;
  final String rollNo;
  final String studentId; // '' for roll-based captures
  final String studentName; // '' for roll-based captures
  final bool uploaded;
  final String? serverUrl;
  final DateTime capturedAt;

  const CapturedImageRecord({
    required this.filePath,
    required this.schoolId,
    required this.schoolCode,
    required this.className,
    required this.rollNo,
    this.studentId = '',
    this.studentName = '',
    required this.uploaded,
    this.serverUrl,
    required this.capturedAt,
  });

  CapturedImageRecord copyWith({
    bool? uploaded,
    String? serverUrl,
  }) {
    return CapturedImageRecord(
      filePath: filePath,
      schoolId: schoolId,
      schoolCode: schoolCode,
      className: className,
      rollNo: rollNo,
      studentId: studentId,
      studentName: studentName,
      uploaded: uploaded ?? this.uploaded,
      serverUrl: serverUrl ?? this.serverUrl,
      capturedAt: capturedAt,
    );
  }

  /// Serialize to a plain Map for Hive storage.
  Map<String, dynamic> toMap() => {
        'filePath': filePath,
        'schoolId': schoolId,
        'schoolCode': schoolCode,
        'className': className,
        'rollNo': rollNo,
        'studentId': studentId,
        'studentName': studentName,
        'uploaded': uploaded,
        'serverUrl': serverUrl,
        'capturedAt': capturedAt.toIso8601String(),
      };

  /// Deserialize from a Hive-stored Map.
  factory CapturedImageRecord.fromMap(Map<dynamic, dynamic> map) =>
      CapturedImageRecord(
        filePath: map['filePath'] as String,
        schoolId: map['schoolId'] as String,
        schoolCode: map['schoolCode'] as String,
        className: map['className'] as String,
        rollNo: map['rollNo'] as String,
        studentId: map['studentId'] as String? ?? '',
        studentName: map['studentName'] as String? ?? '',
        uploaded: map['uploaded'] as bool? ?? false,
        serverUrl: map['serverUrl'] as String?,
        capturedAt: DateTime.tryParse(map['capturedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
