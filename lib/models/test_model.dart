import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosticTestModel {
  final String id;
  final String organizationId;
  final String testName;
  final double price;
  final String turnaroundTime;
  final bool homeCollection;
  final double? homeCollectionSurcharge;

  DiagnosticTestModel({
    required this.id,
    required this.organizationId,
    required this.testName,
    required this.price,
    required this.turnaroundTime,
    this.homeCollection = false,
    this.homeCollectionSurcharge,
  });

  factory DiagnosticTestModel.fromFirestore(DocumentSnapshot doc, String orgId) {
    final data = doc.data() as Map<String, dynamic>;
    return DiagnosticTestModel(
      id: doc.id,
      organizationId: orgId,
      testName: data['test_name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      turnaroundTime: data['turnaround_time'] ?? '',
      homeCollection: data['home_collection'] ?? false,
      homeCollectionSurcharge: data['home_collection_surcharge']?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'test_name': testName,
      'price': price,
      'turnaround_time': turnaroundTime,
      'home_collection': homeCollection,
      'home_collection_surcharge': homeCollectionSurcharge,
    };
  }

  DiagnosticTestModel copyWith({
    String? id,
    String? organizationId,
    String? testName,
    double? price,
    String? turnaroundTime,
    bool? homeCollection,
    double? homeCollectionSurcharge,
  }) {
    return DiagnosticTestModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      testName: testName ?? this.testName,
      price: price ?? this.price,
      turnaroundTime: turnaroundTime ?? this.turnaroundTime,
      homeCollection: homeCollection ?? this.homeCollection,
      homeCollectionSurcharge: homeCollectionSurcharge ?? this.homeCollectionSurcharge,
    );
  }
}
