class ReprintRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String rollNo;
  final String requestType;
  String status; // pending | approved | rejected
  final DateTime createdAt;

  ReprintRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.rollNo,
    this.requestType = 'reprint',
    this.status = 'pending',
    required this.createdAt,
  });
}
