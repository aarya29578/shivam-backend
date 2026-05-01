import 'package:flutter/foundation.dart';
import 'models/reprint_request.dart';

class ReprintRepository extends ChangeNotifier {
  ReprintRepository._privateConstructor();
  static final ReprintRepository instance =
      ReprintRepository._privateConstructor();

  final List<ReprintRequest> _requests = [];

  List<ReprintRequest> get requests => List.unmodifiable(_requests);

  /// Returns the most recent reprint request for a given student, or null.
  ReprintRequest? getByStudentId(String studentId) {
    try {
      return _requests.lastWhere((r) => r.studentId == studentId);
    } catch (_) {
      return null;
    }
  }

  /// Creates a new pending reprint request for a student.
  void createRequest({
    required String studentId,
    required String studentName,
    required String className,
    required String rollNo,
  }) {
    _requests.add(
      ReprintRequest(
        id: 'reprint-${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        studentName: studentName,
        className: className,
        rollNo: rollNo,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Updates the status of an existing request (approved | rejected).
  void updateStatus(String id, String status) {
    final req = _requests.firstWhere((r) => r.id == id);
    req.status = status;
    notifyListeners();
  }
}
