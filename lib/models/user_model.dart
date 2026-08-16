import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? phone;
  final bool profileComplete;
  final String role;
  final String? organizationId;
  final bool accessRevoked;
  final DateTime? accessRevokedAt;
  final String? accessRevokedBy;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.phone,
    this.profileComplete = false,
    this.role = 'patient',
    this.organizationId,
    this.accessRevoked = false,
    this.accessRevokedAt,
    this.accessRevokedBy,
  });

  bool get isPatient => role == 'patient';
  bool get isBedAdmin => role == 'bed_admin' || role == 'hospital_admin';
  bool get isTestAdmin => role == 'test_admin' || role == 'hospital_admin';
  bool get isHospitalAdmin => role == 'hospital_admin';
  bool get isBloodBankAdmin => role == 'blood_bank_admin';
  bool get isAmbulanceAdmin => role == 'ambulance_admin';
  bool get isOrgAdmin =>
      isBedAdmin || isTestAdmin || isBloodBankAdmin || isAmbulanceAdmin;
  bool get isSuperAdmin => role == 'super_admin';
  bool get hasUsableContactProfile {
    final trimmedName = name?.trim() ?? '';
    return trimmedName.length >= 2 &&
        trimmedName.length <= 80 &&
        RegExp(r'^\+?\d{10,15}$').hasMatch(phone ?? '');
  }

  String get roleLabel => switch (role) {
    'bed_admin' => 'Bed Admin',
    'test_admin' => 'Diagnostic Test Admin',
    'hospital_admin' => 'Hospital Admin (Legacy)',
    'blood_bank_admin' => 'Blood Bank Admin',
    'ambulance_admin' => 'Ambulance Admin',
    'super_admin' => 'Super Admin',
    'patient' => 'Patient',
    _ => 'Unknown Role',
  };

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      phone: data['phone'],
      profileComplete: data['profile_complete'] ?? false,
      role: data['role'] ?? 'patient',
      organizationId: data['organization_id'],
      accessRevoked: data['access_revoked'] ?? false,
      accessRevokedAt: (data['access_revoked_at'] as Timestamp?)?.toDate(),
      accessRevokedBy: data['access_revoked_by'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'profile_complete': profileComplete,
      'role': role,
      'organization_id': organizationId,
      'access_revoked': accessRevoked,
      'access_revoked_at': accessRevokedAt == null
          ? null
          : Timestamp.fromDate(accessRevokedAt!),
      'access_revoked_by': accessRevokedBy,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    bool? profileComplete,
    String? role,
    String? organizationId,
    bool? accessRevoked,
    DateTime? accessRevokedAt,
    String? accessRevokedBy,
    bool clearAccessRevocation = false,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileComplete: profileComplete ?? this.profileComplete,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      accessRevoked: accessRevoked ?? this.accessRevoked,
      accessRevokedAt: clearAccessRevocation
          ? null
          : accessRevokedAt ?? this.accessRevokedAt,
      accessRevokedBy: clearAccessRevocation
          ? null
          : accessRevokedBy ?? this.accessRevokedBy,
    );
  }
}
