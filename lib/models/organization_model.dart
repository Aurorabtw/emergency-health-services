import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String id;
  final String type;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final String? email;
  final bool verified;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrganizationModel({
    required this.id,
    required this.type,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.email,
    this.verified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrganizationModel(
      id: doc.id,
      type: data['type'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      phone: data['phone'] ?? '',
      email: data['email'],
      verified: data['verified'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'verified': verified,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  OrganizationModel copyWith({
    String? id,
    String? type,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    bool? verified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
