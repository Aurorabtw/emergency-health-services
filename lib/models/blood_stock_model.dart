import 'package:cloud_firestore/cloud_firestore.dart';

class BloodStockModel {
  final String id;
  final String organizationId;
  final String bloodType;
  final int totalUnits;
  final int heldUnits;
  final int issuedUnits;
  final double processingFeePerUnit;
  final DateTime lastUpdated;

  BloodStockModel({
    required this.id,
    required this.organizationId,
    required this.bloodType,
    required this.totalUnits,
    this.heldUnits = 0,
    this.issuedUnits = 0,
    required this.processingFeePerUnit,
    required this.lastUpdated,
  });

  int get availableUnits => (totalUnits - heldUnits - issuedUnits).clamp(0, totalUnits);

  factory BloodStockModel.fromFirestore(DocumentSnapshot doc, String orgId) {
    final data = doc.data() as Map<String, dynamic>;
    return BloodStockModel(
      id: doc.id,
      organizationId: orgId,
      bloodType: data['blood_type'] ?? '',
      totalUnits: data['total_units'] ?? 0,
      heldUnits: data['held_units'] ?? 0,
      issuedUnits: data['issued_units'] ?? 0,
      processingFeePerUnit: (data['processing_fee_per_unit'] ?? 0).toDouble(),
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blood_type': bloodType,
      'total_units': totalUnits,
      'held_units': heldUnits,
      'issued_units': issuedUnits,
      'processing_fee_per_unit': processingFeePerUnit,
      'last_updated': Timestamp.fromDate(lastUpdated),
    };
  }

  BloodStockModel copyWith({
    String? id,
    String? organizationId,
    String? bloodType,
    int? totalUnits,
    int? heldUnits,
    int? issuedUnits,
    double? processingFeePerUnit,
    DateTime? lastUpdated,
  }) {
    return BloodStockModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      bloodType: bloodType ?? this.bloodType,
      totalUnits: totalUnits ?? this.totalUnits,
      heldUnits: heldUnits ?? this.heldUnits,
      issuedUnits: issuedUnits ?? this.issuedUnits,
      processingFeePerUnit: processingFeePerUnit ?? this.processingFeePerUnit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
