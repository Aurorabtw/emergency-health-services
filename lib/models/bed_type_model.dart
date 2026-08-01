import 'package:cloud_firestore/cloud_firestore.dart';

class BedTypeModel {
  final String id;
  final String organizationId;
  final String type;
  final int totalBeds;
  final int heldBeds;
  final int admittedBeds;
  final double pricePerDay;
  final int holdDurationMinutes;

  BedTypeModel({
    required this.id,
    required this.organizationId,
    required this.type,
    required this.totalBeds,
    this.heldBeds = 0,
    this.admittedBeds = 0,
    required this.pricePerDay,
    this.holdDurationMinutes = 30,
  });

  int get availableBeds => totalBeds - heldBeds - admittedBeds;

  factory BedTypeModel.fromFirestore(DocumentSnapshot doc, String orgId) {
    final data = doc.data() as Map<String, dynamic>;
    return BedTypeModel(
      id: doc.id,
      organizationId: orgId,
      type: data['type'] ?? 'General',
      totalBeds: data['total_beds'] ?? 0,
      heldBeds: data['held_beds'] ?? 0,
      admittedBeds: data['admitted_beds'] ?? 0,
      pricePerDay: (data['price_per_day'] ?? 0).toDouble(),
      holdDurationMinutes: data['hold_duration_minutes'] ?? 30,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'total_beds': totalBeds,
      'held_beds': heldBeds,
      'admitted_beds': admittedBeds,
      'price_per_day': pricePerDay,
      'hold_duration_minutes': holdDurationMinutes,
    };
  }

  BedTypeModel copyWith({
    String? id,
    String? organizationId,
    String? type,
    int? totalBeds,
    int? heldBeds,
    int? admittedBeds,
    double? pricePerDay,
    int? holdDurationMinutes,
  }) {
    return BedTypeModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      type: type ?? this.type,
      totalBeds: totalBeds ?? this.totalBeds,
      heldBeds: heldBeds ?? this.heldBeds,
      admittedBeds: admittedBeds ?? this.admittedBeds,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      holdDurationMinutes: holdDurationMinutes ?? this.holdDurationMinutes,
    );
  }
}
