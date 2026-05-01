/// Client Model - Comprehensive data model for school clients
class ClientModel {
  // Basic Info
  final String? id;
  final String schoolName;
  final String? address;
  final String? city;
  final String? contactName;
  final String phone;
  final String? email;

  // GST Details
  final String? gstNumber;
  final String? gstName;
  final String? gstStateCode;
  final String? gstAddress;

  // Delivery & Transport
  final String? deliveryMode; // 'Bus' or 'Courier'
  final String? busStop;
  final String? route;

  // Type
  final String? clientType; // 'School', 'Coaching', 'Other'

  // Location Details
  final String? state;
  final String? district;
  final String? pincode;

  // Extra
  final String? schoolUniqueId;

  // Metadata
  final String vendorId;
  final String? createdAt;
  final String? updatedAt;

  ClientModel({
    this.id,
    required this.schoolName,
    this.address,
    this.city,
    this.contactName,
    required this.phone,
    this.email,
    this.gstNumber,
    this.gstName,
    this.gstStateCode,
    this.gstAddress,
    this.deliveryMode,
    this.busStop,
    this.route,
    this.clientType,
    this.state,
    this.district,
    this.pincode,
    this.schoolUniqueId,
    required this.vendorId,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert ClientModel to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'schoolName': schoolName,
      'address': address,
      'city': city,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'gstNumber': gstNumber,
      'gstName': gstName,
      'gstStateCode': gstStateCode,
      'gstAddress': gstAddress,
      'deliveryMode': deliveryMode,
      'busStop': busStop,
      'route': route,
      'clientType': clientType,
      'state': state,
      'district': district,
      'pincode': pincode,
      'schoolUniqueId': schoolUniqueId,
      'vendorId': vendorId,
    };
  }

  /// Create ClientModel from JSON (API response)
  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      schoolName: json['schoolName'] as String? ?? '',
      address: json['address'] as String?,
      city: json['city'] as String?,
      contactName: json['contactName'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      gstNumber: json['gstNumber'] as String?,
      gstName: json['gstName'] as String?,
      gstStateCode: json['gstStateCode'] as String?,
      gstAddress: json['gstAddress'] as String?,
      deliveryMode: json['deliveryMode'] as String?,
      busStop: json['busStop'] as String?,
      route: json['route'] as String?,
      clientType: json['clientType'] as String?,
      state: json['state'] as String?,
      district: json['district'] as String?,
      pincode: json['pincode'] as String?,
      schoolUniqueId: json['schoolUniqueId'] as String?,
      vendorId: json['vendorId'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// Copy with method for immutability
  ClientModel copyWith({
    String? id,
    String? schoolName,
    String? address,
    String? city,
    String? contactName,
    String? phone,
    String? email,
    String? gstNumber,
    String? gstName,
    String? gstStateCode,
    String? gstAddress,
    String? deliveryMode,
    String? busStop,
    String? route,
    String? clientType,
    String? state,
    String? district,
    String? pincode,
    String? schoolUniqueId,
    String? vendorId,
    String? createdAt,
    String? updatedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      schoolName: schoolName ?? this.schoolName,
      address: address ?? this.address,
      city: city ?? this.city,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      gstName: gstName ?? this.gstName,
      gstStateCode: gstStateCode ?? this.gstStateCode,
      gstAddress: gstAddress ?? this.gstAddress,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      busStop: busStop ?? this.busStop,
      route: route ?? this.route,
      clientType: clientType ?? this.clientType,
      state: state ?? this.state,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      schoolUniqueId: schoolUniqueId ?? this.schoolUniqueId,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ClientModel(id: $id, schoolName: $schoolName)';
}
