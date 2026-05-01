// Shared order-request model & in-memory store used by both teacher
// and principal screens.

enum OrderStatus { pending, approved, rejected }

class OrderItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String selectedTemplate;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.selectedTemplate,
  });
}

class OrderRequest {
  final String id;
  final String teacherName;
  final List<OrderItem> items;
  final double totalPrice;
  final DateTime requestedAt;
  OrderStatus status;
  String? note;

  OrderRequest({
    required this.id,
    required this.teacherName,
    required this.items,
    required this.totalPrice,
    required this.requestedAt,
    this.status = OrderStatus.pending,
    this.note,
  });
}

class OrderRequestStore {
  static final List<OrderRequest> _requests = [];
  static int _idCounter = 1;

  static List<OrderRequest> get all => List.unmodifiable(_requests);

  static OrderRequest submit({
    required String teacherName,
    required List<OrderItem> items,
    required double totalPrice,
  }) {
    final req = OrderRequest(
      id: 'ORD-${_idCounter.toString().padLeft(3, '0')}',
      teacherName: teacherName,
      items: items,
      totalPrice: totalPrice,
      requestedAt: DateTime.now(),
    );
    _idCounter++;
    _requests.insert(0, req);
    return req;
  }

  static void approve(String id, {String? note}) {
    final req = _requests.firstWhere((r) => r.id == id);
    req.status = OrderStatus.approved;
    req.note = note;
  }

  static void reject(String id, {String? note}) {
    final req = _requests.firstWhere((r) => r.id == id);
    req.status = OrderStatus.rejected;
    req.note = note;
  }
}
