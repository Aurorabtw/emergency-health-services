import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosticTestModel {
  final String id;
  final String organizationId;
  final String? catalogTestId;
  final String testName;
  final double price;
  final String turnaroundTime;
  final bool homeCollection;
  final double? homeCollectionSurcharge;
  final int slotDurationMinutes;
  final bool isAvailable;
  final int dailyCapacity;

  DiagnosticTestModel({
    required this.id,
    required this.organizationId,
    this.catalogTestId,
    required this.testName,
    required this.price,
    required this.turnaroundTime,
    this.homeCollection = false,
    this.homeCollectionSurcharge,
    this.slotDurationMinutes = 15,
    this.isAvailable = true,
    this.dailyCapacity = 100,
  });

  factory DiagnosticTestModel.fromFirestore(
    DocumentSnapshot doc,
    String orgId,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return DiagnosticTestModel(
      id: doc.id,
      organizationId: orgId,
      catalogTestId: data['catalog_test_id'],
      testName: data['test_name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      turnaroundTime: data['turnaround_time'] ?? '',
      homeCollection: data['home_collection'] ?? false,
      homeCollectionSurcharge: data['home_collection_surcharge']?.toDouble(),
      slotDurationMinutes:
          (data['slot_duration_minutes'] as num?)?.toInt() ?? 15,
      isAvailable: data['is_available'] ?? true,
      dailyCapacity: (data['daily_capacity'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'catalog_test_id': catalogTestId,
      'test_name': testName,
      'price': price,
      'turnaround_time': turnaroundTime,
      'home_collection': homeCollection,
      'home_collection_surcharge': homeCollectionSurcharge,
      'slot_duration_minutes': slotDurationMinutes,
      'is_available': isAvailable,
      'daily_capacity': dailyCapacity,
    };
  }

  DiagnosticTestModel copyWith({
    String? id,
    String? organizationId,
    String? catalogTestId,
    String? testName,
    double? price,
    String? turnaroundTime,
    bool? homeCollection,
    double? homeCollectionSurcharge,
    int? slotDurationMinutes,
    bool? isAvailable,
    int? dailyCapacity,
  }) {
    return DiagnosticTestModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      catalogTestId: catalogTestId ?? this.catalogTestId,
      testName: testName ?? this.testName,
      price: price ?? this.price,
      turnaroundTime: turnaroundTime ?? this.turnaroundTime,
      homeCollection: homeCollection ?? this.homeCollection,
      homeCollectionSurcharge:
          homeCollectionSurcharge ?? this.homeCollectionSurcharge,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      isAvailable: isAvailable ?? this.isAvailable,
      dailyCapacity: dailyCapacity ?? this.dailyCapacity,
    );
  }
}

class DiagnosticTestCatalogModel {
  final String id;
  final String name;
  final bool active;
  final DateTime createdAt;

  const DiagnosticTestCatalogModel({
    required this.id,
    required this.name,
    this.active = true,
    required this.createdAt,
  });

  String get normalizedName => name.trim().toLowerCase();

  factory DiagnosticTestCatalogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiagnosticTestCatalogModel(
      id: doc.id,
      name: data['name'] ?? '',
      active: data['active'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'normalized_name': normalizedName,
      'active': active,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
