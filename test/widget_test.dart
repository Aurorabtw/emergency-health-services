import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_services/models/booking_request_model.dart';
import 'package:hospital_services/models/user_model.dart';

void main() {
  UserModel userWithRole(String role) {
    return UserModel(uid: 'user-id', email: 'admin@example.com', role: role);
  }

  test('service admin roles only grant their own service access', () {
    final bedAdmin = userWithRole('bed_admin');
    final testAdmin = userWithRole('test_admin');

    expect(bedAdmin.isBedAdmin, isTrue);
    expect(bedAdmin.isTestAdmin, isFalse);
    expect(testAdmin.isTestAdmin, isTrue);
    expect(testAdmin.isBedAdmin, isFalse);
    expect(bedAdmin.isOrgAdmin, isTrue);
    expect(testAdmin.isOrgAdmin, isTrue);
  });

  test('blood and ambulance roles remain service scoped', () {
    final bloodAdmin = userWithRole('blood_bank_admin');
    final ambulanceAdmin = userWithRole('ambulance_admin');

    expect(bloodAdmin.isBloodBankAdmin, isTrue);
    expect(bloodAdmin.isBedAdmin, isFalse);
    expect(ambulanceAdmin.isAmbulanceAdmin, isTrue);
    expect(ambulanceAdmin.isTestAdmin, isFalse);
  });

  test('legacy hospital admin retains bed and test access', () {
    final legacyAdmin = userWithRole('hospital_admin');

    expect(legacyAdmin.isBedAdmin, isTrue);
    expect(legacyAdmin.isTestAdmin, isTrue);
    expect(legacyAdmin.roleLabel, 'Hospital Admin (Legacy)');
  });

  test('ambulance booking stores its assigned vehicle', () {
    final booking = BookingRequestModel(
      id: 'booking-id',
      type: 'ambulance',
      organizationId: 'operator-id',
      userId: 'patient-id',
      patientName: 'Patient',
      contactNumber: '01700000000',
      createdAt: DateTime(2026),
      ambulanceType: 'ICU',
    ).copyWith(ambulanceId: 'vehicle-id');

    expect(booking.ambulanceId, 'vehicle-id');
    expect(booking.toFirestore()['ambulance_id'], 'vehicle-id');
  });
}
