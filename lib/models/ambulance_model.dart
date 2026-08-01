import 'package:cloud_firestore/cloud_firestore.dart';

class AmbulanceModel {
  final String id;
  final String organizationId;
  final String type;
  final String status;
  final double baseFare;
  final double? perKmRate;

  AmbulanceModel({
    required this.id,
    required this.organizationId,
    required this.type,
    this.status = 'available',
    required this.baseFare,
    this.perKmRate,
  });

  bool get isAvailable => status == 'available';

  factory AmbulanceModel.fromFirestore(DocumentSnapshot doc, String orgId) {
    final data = doc.data() as Map<String, dynamic>;
    return AmbulanceModel(
      id: doc.id,
      organizationId: orgId,
      type: data['type'] ?? 'Basic',
      status: data['status'] ?? 'available',
      baseFare: (data['base_fare'] ?? 0).toDouble(),
      perKmRate: data['per_km_rate']?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'status': status,
      'base_fare': baseFare,
      'per_km_rate': perKmRate,
    };
  }

  AmbulanceModel copyWith({
    String? id,
    String? organizationId,
    String? type,
    String? status,
    double? baseFare,
    double? perKmRate,
  }) {
    return AmbulanceModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      type: type ?? this.type,
      status: status ?? this.status,
      baseFare: baseFare ?? this.baseFare,
      perKmRate: perKmRate ?? this.perKmRate,
    );
  }
}
