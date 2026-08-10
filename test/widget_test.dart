import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_services/models/booking_request_model.dart';
import 'package:hospital_services/models/test_model.dart';
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

  test('diagnostic test stores its queue slot duration', () {
    final diagnosticTest = DiagnosticTestModel(
      id: 'cbc',
      organizationId: 'hospital-id',
      catalogTestId: 'catalog-cbc',
      testName: 'CBC',
      price: 500,
      turnaroundTime: '24 hours',
      slotDurationMinutes: 12,
      dailyCapacity: 100,
      isAvailable: true,
    );

    expect(diagnosticTest.toFirestore()['slot_duration_minutes'], 12);
    expect(diagnosticTest.toFirestore()['catalog_test_id'], 'catalog-cbc');
    expect(diagnosticTest.toFirestore()['daily_capacity'], 100);
    expect(diagnosticTest.toFirestore()['is_available'], isTrue);
    expect(
      diagnosticTest.copyWith(testName: 'CBC Plus').slotDurationMinutes,
      12,
    );
  });

  test('diagnostic serial receipt preserves queue details', () {
    final arrival = DateTime(2026, 8, 10, 14, 30);
    final booking = BookingRequestModel(
      id: 'test-receipt-id',
      type: 'test',
      organizationId: 'hospital-id',
      organizationName: 'Mirpur Hospital',
      userId: 'patient-id',
      patientName: 'Patient',
      contactNumber: '01700000000',
      createdAt: DateTime(2026, 8, 10, 13),
      estimatedPrice: 500,
      testId: 'cbc',
      testName: 'CBC',
      serialNumber: 7,
      queueDate: '2026-08-10',
      queueYear: 2026,
      queueMonth: 8,
      queueDay: 10,
      queueCounterId: 'cbc',
      estimatedArrivalTime: arrival,
    );
    final data = booking.toFirestore();

    expect(data['test_id'], 'cbc');
    expect(data['test_name'], 'CBC');
    expect(data['serial_number'], 7);
    expect(data['queue_date'], '2026-08-10');
    expect(data['queue_year'], 2026);
    expect(data['queue_month'], 8);
    expect(data['queue_day'], 10);
    expect(data['queue_counter_id'], 'cbc');
    expect(booking.copyWith(status: 'confirmed').serialNumber, 7);
  });
}
