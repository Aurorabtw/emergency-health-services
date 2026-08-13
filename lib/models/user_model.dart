import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? phone;
  final bool profileComplete;
  final String role;
  final String? organizationId;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.phone,
    this.profileComplete = false,
    this.role = 'patient',
    this.organizationId,
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
    final cleanedPhone = phone?.replaceAll(RegExp(r'[\s\-\(\)]'), '') ?? '';
    return (name?.trim().length ?? 0) >= 2 &&
        RegExp(r'^\+?\d{10,15}$').hasMatch(cleanedPhone);
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
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileComplete: profileComplete ?? this.profileComplete,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
    );
  }
}
