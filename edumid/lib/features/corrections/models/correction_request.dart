class CorrectionRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String rollNo;
  final Map<String, String> requestedChanges;
  String status; // pending | approved | rejected
  final String? note;
  String? teacherNote; // set by teacher when rejecting
  final DateTime submittedAt;

  CorrectionRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.rollNo,
    required this.requestedChanges,
    this.status = 'pending',
    this.note,
    this.teacherNote,
    required this.submittedAt,
  });
}
