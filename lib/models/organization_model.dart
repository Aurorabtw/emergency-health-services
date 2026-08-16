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
  final String lifecycleState;
  final bool archived;
  final DateTime? archiveLockAt;
  final String? archiveLockBy;
  final DateTime? archivedAt;
  final String? archivedBy;
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
    this.lifecycleState = 'active',
    this.archived = false,
    this.archiveLockAt,
    this.archiveLockBy,
    this.archivedAt,
    this.archivedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final legacyArchived = data['archived'] as bool? ?? false;
    final lifecycleState =
        data['lifecycle_state'] as String? ??
        (legacyArchived ? 'archived' : 'active');
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
      lifecycleState: lifecycleState,
      archived: legacyArchived || lifecycleState == 'archived',
      archiveLockAt: (data['archive_lock_at'] as Timestamp?)?.toDate(),
      archiveLockBy: data['archive_lock_by'],
      archivedAt: (data['archived_at'] as Timestamp?)?.toDate(),
      archivedBy: data['archived_by'],
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
      'lifecycle_state': lifecycleState,
      'archived': archived,
      'archive_lock_at': archiveLockAt == null
          ? null
          : Timestamp.fromDate(archiveLockAt!),
      'archive_lock_by': archiveLockBy,
      'archived_at': archivedAt == null
          ? null
          : Timestamp.fromDate(archivedAt!),
      'archived_by': archivedBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isActive => lifecycleState == 'active' && !archived;
  bool get isArchiving => lifecycleState == 'archiving' && !archived;

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
    String? lifecycleState,
    bool? archived,
    DateTime? archiveLockAt,
    String? archiveLockBy,
    DateTime? archivedAt,
    String? archivedBy,
    bool clearArchive = false,
    bool clearArchiveLock = false,
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
      lifecycleState: lifecycleState ?? this.lifecycleState,
      archived: archived ?? this.archived,
      archiveLockAt: clearArchiveLock
          ? null
          : archiveLockAt ?? this.archiveLockAt,
      archiveLockBy: clearArchiveLock
          ? null
          : archiveLockBy ?? this.archiveLockBy,
      archivedAt: clearArchive ? null : archivedAt ?? this.archivedAt,
      archivedBy: clearArchive ? null : archivedBy ?? this.archivedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
