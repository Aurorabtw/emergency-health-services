import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRequestModel {
  final String id;
  final String type;
  final String organizationId;
  final String? organizationName;
  final String userId;
  final String patientName;
  final String contactNumber;
  final String status;
  final DateTime? heldUntil;
  final double? estimatedPrice;
  final DateTime createdAt;

  // Bed-specific
  final String? bedType;
  final String? prescriptionImageUrl;

  // Ambulance-specific
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final String? ambulanceType;
  final String? ambulanceId;
  final String? patientConditionNotes;
  final String? pickupAddress;
  final String? destinationAddress;

  // Blood-specific
  final String? bloodType;
  final int? unitsNeeded;
  final String? hospitalName;
  final String? prescribingDoctor;

  // Diagnostic test-specific
  final String? testId;
  final String? testName;
  final int? serialNumber;
  final String? queueDate;
  final int? queueYear;
  final int? queueMonth;
  final int? queueDay;
  final String? queueCounterId;
  final DateTime? estimatedArrivalTime;
  final DateTime? calledAt;
  final DateTime? completedAt;

  BookingRequestModel({
    required this.id,
    required this.type,
    required this.organizationId,
    this.organizationName,
    required this.userId,
    required this.patientName,
    required this.contactNumber,
    this.status = 'pending',
    this.heldUntil,
    this.estimatedPrice,
    required this.createdAt,
    this.bedType,
    this.prescriptionImageUrl,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.ambulanceType,
    this.ambulanceId,
    this.patientConditionNotes,
    this.pickupAddress,
    this.destinationAddress,
    this.bloodType,
    this.unitsNeeded,
    this.hospitalName,
    this.prescribingDoctor,
    this.testId,
    this.testName,
    this.serialNumber,
    this.queueDate,
    this.queueYear,
    this.queueMonth,
    this.queueDay,
    this.queueCounterId,
    this.estimatedArrivalTime,
    this.calledAt,
    this.completedAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isAdmitted => status == 'admitted';
  bool get isExpired => status == 'expired';
  bool get isRejected => status == 'rejected';
  bool get isTerminal => isAdmitted || isExpired || isRejected;

  bool get isHoldExpired {
    if (!isConfirmed || heldUntil == null) return false;
    return DateTime.now().isAfter(heldUntil!);
  }

  factory BookingRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingRequestModel(
      id: doc.id,
      type: data['type'] ?? '',
      organizationId: data['organization_id'] ?? '',
      organizationName: data['organization_name'],
      userId: data['user_id'] ?? '',
      patientName: data['patient_name'] ?? '',
      contactNumber: data['contact_number'] ?? '',
      status: data['status'] ?? 'pending',
      heldUntil: (data['held_until'] as Timestamp?)?.toDate(),
      estimatedPrice: data['estimated_price']?.toDouble(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bedType: data['bed_type'],
      prescriptionImageUrl: data['prescription_image_url'],
      pickupLat: data['pickup_lat']?.toDouble(),
      pickupLng: data['pickup_lng']?.toDouble(),
      destinationLat: data['destination_lat']?.toDouble(),
      destinationLng: data['destination_lng']?.toDouble(),
      ambulanceType: data['ambulance_type'],
      ambulanceId: data['ambulance_id'],
      patientConditionNotes: data['patient_condition_notes'],
      pickupAddress: data['pickup_address'],
      destinationAddress: data['destination_address'],
      bloodType: data['blood_type'],
      unitsNeeded: data['units_needed'],
      hospitalName: data['hospital_name'],
      prescribingDoctor: data['prescribing_doctor'],
      testId: data['test_id'],
      testName: data['test_name'],
      serialNumber: data['serial_number'],
      queueDate: data['queue_date'],
      queueYear: data['queue_year'],
      queueMonth: data['queue_month'],
      queueDay: data['queue_day'],
      queueCounterId: data['queue_counter_id'],
      estimatedArrivalTime: (data['estimated_arrival_time'] as Timestamp?)
          ?.toDate(),
      calledAt: (data['called_at'] as Timestamp?)?.toDate(),
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'type': type,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'user_id': userId,
      'patient_name': patientName,
      'contact_number': contactNumber,
      'status': status,
      'held_until': heldUntil != null ? Timestamp.fromDate(heldUntil!) : null,
      'estimated_price': estimatedPrice,
      'created_at': Timestamp.fromDate(createdAt),
    };

    if (type == 'bed') {
      map['bed_type'] = bedType;
      map['prescription_image_url'] = prescriptionImageUrl;
    } else if (type == 'ambulance') {
      map['pickup_lat'] = pickupLat;
      map['pickup_lng'] = pickupLng;
      map['destination_lat'] = destinationLat;
      map['destination_lng'] = destinationLng;
      map['ambulance_type'] = ambulanceType;
      map['ambulance_id'] = ambulanceId;
      map['patient_condition_notes'] = patientConditionNotes;
      map['pickup_address'] = pickupAddress;
      map['destination_address'] = destinationAddress;
    } else if (type == 'blood') {
      map['blood_type'] = bloodType;
      map['units_needed'] = unitsNeeded;
      map['hospital_name'] = hospitalName;
      map['prescribing_doctor'] = prescribingDoctor;
    } else if (type == 'test') {
      map['test_id'] = testId;
      map['test_name'] = testName;
      map['serial_number'] = serialNumber;
      map['queue_date'] = queueDate;
      map['queue_year'] = queueYear;
      map['queue_month'] = queueMonth;
      map['queue_day'] = queueDay;
      map['queue_counter_id'] = queueCounterId;
      map['estimated_arrival_time'] = estimatedArrivalTime != null
          ? Timestamp.fromDate(estimatedArrivalTime!)
          : null;
      map['called_at'] = calledAt != null
          ? Timestamp.fromDate(calledAt!)
          : null;
      map['completed_at'] = completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null;
    }

    return map;
  }

  BookingRequestModel copyWith({
    String? id,
    String? type,
    String? organizationId,
    String? organizationName,
    String? userId,
    String? patientName,
    String? contactNumber,
    String? status,
    DateTime? heldUntil,
    double? estimatedPrice,
    DateTime? createdAt,
    String? bedType,
    String? prescriptionImageUrl,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    String? ambulanceType,
    String? ambulanceId,
    String? patientConditionNotes,
    String? pickupAddress,
    String? destinationAddress,
    String? bloodType,
    int? unitsNeeded,
    String? hospitalName,
    String? prescribingDoctor,
    String? testId,
    String? testName,
    int? serialNumber,
    String? queueDate,
    int? queueYear,
    int? queueMonth,
    int? queueDay,
    String? queueCounterId,
    DateTime? estimatedArrivalTime,
    DateTime? calledAt,
    DateTime? completedAt,
  }) {
    return BookingRequestModel(
      id: id ?? this.id,
      type: type ?? this.type,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      userId: userId ?? this.userId,
      patientName: patientName ?? this.patientName,
      contactNumber: contactNumber ?? this.contactNumber,
      status: status ?? this.status,
      heldUntil: heldUntil ?? this.heldUntil,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      createdAt: createdAt ?? this.createdAt,
      bedType: bedType ?? this.bedType,
      prescriptionImageUrl: prescriptionImageUrl ?? this.prescriptionImageUrl,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      ambulanceType: ambulanceType ?? this.ambulanceType,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      patientConditionNotes:
          patientConditionNotes ?? this.patientConditionNotes,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      bloodType: bloodType ?? this.bloodType,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      hospitalName: hospitalName ?? this.hospitalName,
      prescribingDoctor: prescribingDoctor ?? this.prescribingDoctor,
      testId: testId ?? this.testId,
      testName: testName ?? this.testName,
      serialNumber: serialNumber ?? this.serialNumber,
      queueDate: queueDate ?? this.queueDate,
      queueYear: queueYear ?? this.queueYear,
      queueMonth: queueMonth ?? this.queueMonth,
      queueDay: queueDay ?? this.queueDay,
      queueCounterId: queueCounterId ?? this.queueCounterId,
      estimatedArrivalTime: estimatedArrivalTime ?? this.estimatedArrivalTime,
      calledAt: calledAt ?? this.calledAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
