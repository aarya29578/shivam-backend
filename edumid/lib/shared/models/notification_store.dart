import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum NotifCategory { announcement, attendance, correction, order, general }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotifCategory category;
  final DateTime createdAt;
  bool isRead;
  bool isFavourite;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.isFavourite = false,
  });

  IconData get icon {
    switch (category) {
      case NotifCategory.announcement:
        return Icons.campaign_rounded;
      case NotifCategory.attendance:
        return Icons.how_to_reg_rounded;
      case NotifCategory.correction:
        return Icons.rate_review_rounded;
      case NotifCategory.order:
        return Icons.receipt_long_rounded;
      case NotifCategory.general:
        return Icons.info_outline_rounded;
    }
  }

  Color get color {
    switch (category) {
      case NotifCategory.announcement:
        return AppColors.primary;
      case NotifCategory.attendance:
        return AppColors.secondary;
      case NotifCategory.correction:
        return const Color(0xFFD97706);
      case NotifCategory.order:
        return AppColors.success;
      case NotifCategory.general:
        return const Color(0xFF6B7280);
    }
  }
}

class NotificationStore {
  static final List<AppNotification> _items = [
    AppNotification(
      id: 'n1',
      title: 'Annual Sports Day',
      body:
          'Annual Sports Day is scheduled for March 20. All teachers must report by 8:00 AM.',
      category: NotifCategory.announcement,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    AppNotification(
      id: 'n2',
      title: 'Attendance Submitted',
      body:
          'Class 10-B attendance for today has been marked — 38/40 students present.',
      category: NotifCategory.attendance,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    AppNotification(
      id: 'n3',
      title: 'Correction Review Pending',
      body: 'You have 3 correction review requests awaiting your approval.',
      category: NotifCategory.correction,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n4',
      title: 'Order Request Approved',
      body:
          'Your order request ORD-001 for Student ID Cards has been approved by the principal.',
      category: NotifCategory.order,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isFavourite: true,
    ),
    AppNotification(
      id: 'n5',
      title: 'Parent-Teacher Meeting',
      body:
          'PTM is scheduled for March 18. Please prepare all student report cards in advance.',
      category: NotifCategory.announcement,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      isFavourite: true,
    ),
    AppNotification(
      id: 'n6',
      title: 'New Student Enrolled',
      body: 'A new student Aarav Sharma has been added to Class 8-A.',
      category: NotifCategory.general,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
    AppNotification(
      id: 'n7',
      title: 'ID Card Batch Ready',
      body:
          'The ID card batch for Class 2024 is ready for printing — 142 cards queued.',
      category: NotifCategory.order,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  static List<AppNotification> get all => List.unmodifiable(_items);

  static List<AppNotification> get unread =>
      _items.where((n) => !n.isRead).toList();

  static List<AppNotification> get read =>
      _items.where((n) => n.isRead).toList();

  static List<AppNotification> get favourites =>
      _items.where((n) => n.isFavourite).toList();

  static int get unreadCount => _items.where((n) => !n.isRead).length;

  static void markRead(String id) {
    final n = _items.firstWhere((n) => n.id == id);
    n.isRead = true;
  }

  static void markAllRead() {
    for (final n in _items) {
      n.isRead = true;
    }
  }

  static void toggleFavourite(String id) {
    final n = _items.firstWhere((n) => n.id == id);
    n.isFavourite = !n.isFavourite;
  }
}
