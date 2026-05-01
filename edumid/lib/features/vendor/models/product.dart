class Product {
  final String id;
  final String name;
  final String category;
  final String description;
  final double vendorPrice;
  final double clientPrice;
  final double publicPrice;
  final double principalPrice;
  final double studentPrice;
  final List<String> images;
  final String? thumbnailImage;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.vendorPrice,
    required this.clientPrice,
    required this.publicPrice,
    required this.principalPrice,
    required this.studentPrice,
    required this.images,
    this.thumbnailImage,
  });

  /// Full role-based pricing map.
  Map<String, double> get pricing => {
        'vendor': vendorPrice,
        'client': clientPrice,
        'public': publicPrice,
        'principal': principalPrice,
        'student': studentPrice,
      };

  /// Price for the given role, falling back to publicPrice.
  double priceForRole(String role) => pricing[role] ?? publicPrice;

  /// First image URL, or null.
  String? get image => images.isNotEmpty ? images.first : thumbnailImage;

  static double _num(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'general',
        description: json['description']?.toString() ?? '',
        vendorPrice: _num(json['vendorPrice'] ?? json['price']),
        clientPrice: _num(json['clientPrice']),
        publicPrice: _num(json['publicPrice'] ?? json['price']),
        principalPrice: _num(json['principalPrice']),
        studentPrice: _num(json['studentPrice']),
        images: (json['images'] as List<dynamic>?)
                ?.map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        thumbnailImage: json['thumbnailImage']?.toString(),
      );
}
