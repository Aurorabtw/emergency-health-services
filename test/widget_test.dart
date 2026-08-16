import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_services/models/booking_request_model.dart';
import 'package:hospital_services/models/test_model.dart';
import 'package:hospital_services/models/user_model.dart';
import 'package:hospital_services/shared/utils/validators.dart';

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

  test('profile completion requires a usable name and phone', () {
    final incomplete = UserModel(
      uid: 'patient-id',
      email: 'patient@example.com',
      name: 'Patient',
      profileComplete: true,
    );
    final complete = incomplete.copyWith(phone: '+8801712345678');

    expect(incomplete.hasUsableContactProfile, isFalse);
    expect(complete.hasUsableContactProfile, isTrue);
  });

  test('unknown roles are not presented as patients', () {
    expect(userWithRole('unexpected_role').roleLabel, 'Unknown Role');
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
      ambulanceReferenceId: 'available-vehicle-id',
      prescriptionDocumentId: 'booking-id',
    ).copyWith(ambulanceId: 'vehicle-id');

    expect(booking.ambulanceId, 'vehicle-id');
    expect(booking.toFirestore()['ambulance_id'], 'vehicle-id');
    expect(
      booking.toFirestore()['ambulance_reference_id'],
      'available-vehicle-id',
    );
    expect(
      booking.toFirestore()['prescription_document_id'],
      'booking-id',
    );
  });

  test('bed and blood bookings preserve authoritative references', () {
    final bed = BookingRequestModel(
      id: 'bed-booking-id',
      type: 'bed',
      organizationId: 'hospital-id',
      organizationName: 'Hospital',
      userId: 'patient-id',
      patientName: 'Patient',
      contactNumber: '01700000000',
      createdAt: DateTime(2026),
      bedId: 'bed-id',
      bedType: 'ICU',
      prescriptionDocumentId: 'bed-booking-id',
    ).toFirestore();
    final blood = BookingRequestModel(
      id: 'blood-booking-id',
      type: 'blood',
      organizationId: 'blood-bank-id',
      organizationName: 'Blood Bank',
      userId: 'patient-id',
      patientName: 'Patient',
      contactNumber: '01700000000',
      createdAt: DateTime(2026),
      bloodStockId: 'stock-id',
      bloodType: 'A+',
      unitsNeeded: 2,
      hospitalId: 'hospital-id',
      hospitalName: 'Hospital',
      prescribingDoctor: 'Doctor',
      prescriptionDocumentId: 'blood-booking-id',
    ).toFirestore();

    expect(bed['bed_id'], 'bed-id');
    expect(blood['blood_stock_id'], 'stock-id');
    expect(blood['hospital_id'], 'hospital-id');
    expect(
      blood['prescription_document_id'],
      'blood-booking-id',
    );
  });

  test('positive integer validation rejects zero units', () {
    expect(Validators.validatePositiveInt('0', 'Units'), isNotNull);
    expect(Validators.validatePositiveInt('1', 'Units'), isNull);
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
