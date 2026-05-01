class Client {
  final String id;
  final String name;
  final String schoolCode;

  const Client({
    required this.id,
    required this.name,
    this.schoolCode = '',
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        schoolCode: (json['schoolCode'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Client && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
