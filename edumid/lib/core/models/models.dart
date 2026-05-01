import '../../core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final UserRole role;
  final String? schoolId;
  final String? vendorId;
  final bool isVerified;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.role,
    this.schoolId,
    this.vendorId,
    required this.isVerified,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        avatarUrl: json['avatar_url'],
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.student,
        ),
        schoolId: json['school_id'],
        vendorId: json['vendor_id'],
        isVerified: json['is_verified'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role.name,
        'school_id': schoolId,
        'vendor_id': vendorId,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
        schoolId: schoolId,
        vendorId: vendorId,
        isVerified: isVerified,
        createdAt: createdAt,
      );
}

class StudentModel {
  final String id;
  final String name;
  final String rollNumber;
  final String className;
  final String section;
  final String schoolId;
  final String? photoUrl;
  final String? parentName;
  final String? parentPhone;
  final String bloodGroup;
  final DateTime dob;
  final String address;
  final bool hasIdCard;
  final String? idCardUrl;

  const StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.className,
    required this.section,
    required this.schoolId,
    this.photoUrl,
    this.parentName,
    this.parentPhone,
    required this.bloodGroup,
    required this.dob,
    required this.address,
    required this.hasIdCard,
    this.idCardUrl,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(
        id: json['id'],
        name: json['name'],
        rollNumber: json['roll_number'],
        className: json['class'],
        section: json['section'],
        schoolId: json['school_id'],
        photoUrl: json['photo_url'],
        parentName: json['parent_name'],
        parentPhone: json['parent_phone'],
        bloodGroup: json['blood_group'],
        dob: DateTime.parse(json['dob']),
        address: json['address'],
        hasIdCard: json['has_id_card'] ?? false,
        idCardUrl: json['id_card_url'],
      );
}

class OrderModel {
  final String id;
  final String title;
  final String schoolName;
  final String vendorId;
  final int totalCards;
  final int completedCards;
  final OrderStage stage;
  final DateTime createdAt;
  final DateTime? expectedDelivery;
  final double amount;
  final String? trackingNumber;

  const OrderModel({
    required this.id,
    required this.title,
    required this.schoolName,
    required this.vendorId,
    required this.totalCards,
    required this.completedCards,
    required this.stage,
    required this.createdAt,
    this.expectedDelivery,
    required this.amount,
    this.trackingNumber,
  });

  double get progress => totalCards > 0 ? completedCards / totalCards : 0.0;
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });
}

class TransactionModel {
  final String id;
  final double amount;
  final String type; // credit | debit
  final String description;
  final DateTime createdAt;
  final String status; // success | pending | failed

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
    required this.status,
  });
}
