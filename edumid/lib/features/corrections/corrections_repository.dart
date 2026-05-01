import 'package:flutter/foundation.dart';
import 'models/correction_request.dart';

class CorrectionsRepository {
  CorrectionsRepository._privateConstructor();
  static final CorrectionsRepository instance =
      CorrectionsRepository._privateConstructor();

  // Simple in-memory student data store for demo purposes.
  final Map<String, Map<String, String>> _studentData = {
    'student-23': {
      'Name': 'Arjun Sharma',
      'Class': 'X-A',
      'Roll No.': '23',
      'DOB': '15 Jan 2008',
      'Blood Group': 'B+',
      'Phone': '+91 98765 43210',
      'Address': '123 School Lane, City',
    },
    'student-01': {
      'Name': 'Rahul Kumar',
      'Class': 'X-A',
      'Roll No.': '01',
      'DOB': '10 Mar 2008',
      'Blood Group': 'O+',
      'Phone': '+91 99887 76655',
      'Address': '45 MG Road, Delhi',
    },
    'student-05': {
      'Name': 'Priya Patel',
      'Class': 'X-B',
      'Roll No.': '05',
      'DOB': '22 Jul 2008',
      'Blood Group': 'A+',
      'Phone': '+91 91234 56789',
      'Address': '78 Lake View, Mumbai',
    },
    'student-12': {
      'Name': 'Rohit Verma',
      'Class': 'IX-A',
      'Roll No.': '12',
      'DOB': '5 Sep 2009',
      'Blood Group': 'AB+',
      'Phone': '+91 87654 32100',
      'Address': '9 Green Park, Jaipur',
    },
    'student-08': {
      'Name': 'Sneha Rathi',
      'Class': 'X-A',
      'Roll No.': '08',
      'DOB': '14 Dec 2008',
      'Blood Group': 'B-',
      'Phone': '+91 95544 11223',
      'Address': '33 Nehru Nagar, Pune',
    },
  };

  late final List<CorrectionRequest> _requests = _seedRequests();

  List<CorrectionRequest> _seedRequests() {
    final base = DateTime(2026, 3, 7);
    return [
      CorrectionRequest(
        id: 'req-001',
        studentId: 'student-01',
        studentName: 'Rahul Kumar',
        className: 'X-A',
        rollNo: '01',
        requestedChanges: {
          'Phone': '+91 99887 11111',
          'Address': '45 MG Road, New Delhi - 110001',
        },
        note: 'Phone number changed, address updated with PIN code.',
        status: 'pending',
        submittedAt: base.subtract(const Duration(hours: 5)),
      ),
      CorrectionRequest(
        id: 'req-002',
        studentId: 'student-23',
        studentName: 'Arjun Sharma',
        className: 'X-A',
        rollNo: '23',
        requestedChanges: {
          'Name': 'Arjun Kumar Sharma',
          'DOB': '15 Jan 2008',
          'Blood Group': 'O+',
        },
        note:
            'Full legal name includes middle name. Blood group corrected after lab test.',
        status: 'pending',
        submittedAt: base.subtract(const Duration(hours: 2)),
      ),
      CorrectionRequest(
        id: 'req-003',
        studentId: 'student-08',
        studentName: 'Sneha Rathi',
        className: 'X-A',
        rollNo: '08',
        requestedChanges: {
          'Phone': '+91 95544 99999',
        },
        note: 'Parent changed contact number.',
        status: 'approved',
        submittedAt: base.subtract(const Duration(days: 1)),
      ),
      CorrectionRequest(
        id: 'req-004',
        studentId: 'student-05',
        studentName: 'Priya Patel',
        className: 'X-B',
        rollNo: '05',
        requestedChanges: {
          'Address': '78 Lake View Apts, Andheri, Mumbai - 400053',
          'Blood Group': 'A-',
        },
        note:
            'Moved to new flat. Blood group was entered incorrectly during admission.',
        status: 'pending',
        submittedAt: base.subtract(const Duration(hours: 10)),
      ),
      CorrectionRequest(
        id: 'req-005',
        studentId: 'student-12',
        studentName: 'Rohit Verma',
        className: 'IX-A',
        rollNo: '12',
        requestedChanges: {
          'Name': 'Rohit Kumar Verma',
          'Phone': '+91 87654 00000',
          'Address': '9 Green Park Colony, Jaipur - 302020',
        },
        note: 'Correcting full name and updating contact details.',
        status: 'pending',
        submittedAt: base.subtract(const Duration(hours: 8)),
      ),
      CorrectionRequest(
        id: 'req-006',
        studentId: 'student-12',
        studentName: 'Rohit Verma',
        className: 'IX-A',
        rollNo: '12',
        requestedChanges: {
          'DOB': '5 September 2009',
        },
        note: 'DOB format correction.',
        status: 'rejected',
        submittedAt: base.subtract(const Duration(days: 2)),
      ),
    ];
  }

  List<CorrectionRequest> listAll() => List.unmodifiable(_requests);

  List<CorrectionRequest> listByClass(String className) =>
      _requests.where((r) => r.className == className).toList();

  List<CorrectionRequest> listByStudent(String studentId) =>
      _requests.where((r) => r.studentId == studentId).toList();

  CorrectionRequest? getById(String id) =>
      _requests.firstWhereOrNull((r) => r.id == id);

  CorrectionRequest createRequest({
    required String studentId,
    required String studentName,
    required String className,
    required String rollNo,
    required Map<String, String> requestedChanges,
    String? note,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final rec = CorrectionRequest(
      id: id,
      studentId: studentId,
      studentName: studentName,
      className: className,
      rollNo: rollNo,
      requestedChanges: Map.from(requestedChanges),
      status: 'pending',
      note: note,
      submittedAt: DateTime.now(),
    );
    _requests.add(rec);
    if (kDebugMode) {
      // ignore: avoid_print
      print('Created correction request: ${rec.id}');
    }
    return rec;
  }

  void approve(String id) {
    final r = getById(id);
    if (r == null) return;
    // apply changes to student data (demo)
    final data = _studentData[r.studentId];
    if (data != null) {
      data.addAll(r.requestedChanges);
    }
    r.status = 'approved';
  }

  void reject(String id, {String? reason}) {
    final r = getById(id);
    if (r == null) return;
    r.status = 'rejected';
    if (reason != null && reason.isNotEmpty) r.teacherNote = reason;
  }

  Map<String, String>? studentData(String studentId) => _studentData[studentId];
}

extension FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
