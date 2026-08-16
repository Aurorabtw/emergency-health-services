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
  final DateTime? confirmedAt;
  final int? holdDurationMinutes;
  final double? estimatedPrice;
  final DateTime createdAt;

  // Bed-specific
  final String? bedId;
  final String? bedType;
  final String? prescriptionDocumentId;
  // Set when the prescription is stored via the Vercel/Cloudinary upload gateway
  // instead of an inline Firestore blob. Equals the booking id.
  final String? prescriptionAssetId;
  // Read-only compatibility for prescriptions uploaded before Firestore migration.
  final String? prescriptionImageUrl;
  final DateTime? admittedAt;
  final DateTime? dischargedAt;

  // Ambulance-specific
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final String? ambulanceType;
  final String? ambulanceReferenceId;
  final String? ambulanceId;
  final String? patientConditionNotes;
  final String? pickupAddress;
  final String? destinationHospitalId;
  final String? destinationAddress;

  // Blood-specific
  final String? bloodStockId;
  final String? bloodType;
  final int? unitsNeeded;
  final String? hospitalId;
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
    this.confirmedAt,
    this.holdDurationMinutes,
    this.estimatedPrice,
    required this.createdAt,
    this.bedId,
    this.bedType,
    this.prescriptionDocumentId,
    this.prescriptionAssetId,
    this.prescriptionImageUrl,
    this.admittedAt,
    this.dischargedAt,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.ambulanceType,
    this.ambulanceReferenceId,
    this.ambulanceId,
    this.patientConditionNotes,
    this.pickupAddress,
    this.destinationHospitalId,
    this.destinationAddress,
    this.bloodStockId,
    this.bloodType,
    this.unitsNeeded,
    this.hospitalId,
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
  bool get isDischarged => status == 'discharged';
  bool get isTerminal => type == 'bed'
      ? isDischarged || isExpired || isRejected
      : isAdmitted || isExpired || isRejected;

  bool get isHoldExpired {
    if (!isConfirmed || heldUntil == null) return false;
    return DateTime.now().isAfter(heldUntil!);
  }

  factory BookingRequestModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    if (rawData is! Map<String, dynamic>) {
      throw FormatException('Booking ${doc.id} is not a document map.');
    }
    final data = rawData;

    String requiredString(String key) {
      final value = data[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Booking ${doc.id} has an invalid $key.');
      }
      return value;
    }

    String? optionalString(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Booking ${doc.id} has an invalid $key.');
      }
      return value;
    }

    double? optionalNumber(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! num) {
        throw FormatException('Booking ${doc.id} has an invalid $key.');
      }
      return value.toDouble();
    }

    int? optionalInt(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! int) {
        throw FormatException('Booking ${doc.id} has an invalid $key.');
      }
      return value;
    }

    DateTime? optionalDate(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! Timestamp) {
        throw FormatException('Booking ${doc.id} has an invalid $key.');
      }
      return value.toDate();
    }

    final type = requiredString('type');
    if (!const {'bed', 'blood', 'ambulance', 'test'}.contains(type)) {
      throw FormatException('Booking ${doc.id} has an invalid type.');
    }
    final status = requiredString('status');
    if (!const {
      'pending',
      'confirmed',
      'admitted',
      'expired',
      'rejected',
      'discharged',
    }.contains(status)) {
      throw FormatException('Booking ${doc.id} has an invalid status.');
    }
    final createdAt = optionalDate('created_at');
    if (createdAt == null) {
      throw FormatException('Booking ${doc.id} has an invalid created_at.');
    }

    final confirmedAt = optionalDate('confirmed_at');
    final holdDurationMinutes = optionalInt('hold_duration_minutes');
    final storedHeldUntil = optionalDate('held_until');
    final effectiveHeldUntil = storedHeldUntil ??
        (confirmedAt != null && holdDurationMinutes != null
            ? confirmedAt.add(Duration(minutes: holdDurationMinutes))
            : null);

    return BookingRequestModel(
      id: doc.id,
      type: type,
      organizationId: requiredString('organization_id'),
      organizationName: requiredString('organization_name'),
      userId: requiredString('user_id'),
      patientName: requiredString('patient_name'),
      contactNumber: requiredString('contact_number'),
      status: status,
      heldUntil: effectiveHeldUntil,
      confirmedAt: confirmedAt,
      holdDurationMinutes: holdDurationMinutes,
      estimatedPrice: optionalNumber('estimated_price'),
      createdAt: createdAt,
      bedId: optionalString('bed_id'),
      bedType: optionalString('bed_type'),
      prescriptionDocumentId: optionalString('prescription_document_id'),
      prescriptionAssetId: optionalString('prescription_asset_id'),
      prescriptionImageUrl: optionalString('prescription_image_url'),
      admittedAt: optionalDate('admitted_at'),
      dischargedAt: optionalDate('discharged_at'),
      pickupLat: optionalNumber('pickup_lat'),
      pickupLng: optionalNumber('pickup_lng'),
      destinationLat: optionalNumber('destination_lat'),
      destinationLng: optionalNumber('destination_lng'),
      ambulanceType: optionalString('ambulance_type'),
      ambulanceReferenceId: optionalString('ambulance_reference_id'),
      ambulanceId: optionalString('ambulance_id'),
      patientConditionNotes: optionalString('patient_condition_notes'),
      pickupAddress: optionalString('pickup_address'),
      destinationHospitalId: optionalString('destination_hospital_id'),
      destinationAddress: optionalString('destination_address'),
      bloodStockId: optionalString('blood_stock_id'),
      bloodType: optionalString('blood_type'),
      unitsNeeded: optionalInt('units_needed'),
      hospitalId: optionalString('hospital_id'),
      hospitalName: optionalString('hospital_name'),
      prescribingDoctor: optionalString('prescribing_doctor'),
      testId: optionalString('test_id'),
      testName: optionalString('test_name'),
      serialNumber: optionalInt('serial_number'),
      queueDate: optionalString('queue_date'),
      queueYear: optionalInt('queue_year'),
      queueMonth: optionalInt('queue_month'),
      queueDay: optionalInt('queue_day'),
      queueCounterId: optionalString('queue_counter_id'),
      estimatedArrivalTime: optionalDate('estimated_arrival_time'),
      calledAt: optionalDate('called_at'),
      completedAt: optionalDate('completed_at'),
    );
  }

  static BookingRequestModel? tryFromFirestore(DocumentSnapshot doc) {
    try {
      return BookingRequestModel.fromFirestore(doc);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
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
    if (confirmedAt != null) {
      map['confirmed_at'] = Timestamp.fromDate(confirmedAt!);
    }
    if (holdDurationMinutes != null) {
      map['hold_duration_minutes'] = holdDurationMinutes;
    }

    if (type == 'bed') {
      map['bed_id'] = bedId;
      map['bed_type'] = bedType;
      if (prescriptionAssetId != null) {
        map['prescription_asset_id'] = prescriptionAssetId;
      } else {
        map['prescription_document_id'] = prescriptionDocumentId;
      }
      if (admittedAt != null) {
        map['admitted_at'] = Timestamp.fromDate(admittedAt!);
      }
      if (dischargedAt != null) {
        map['discharged_at'] = Timestamp.fromDate(dischargedAt!);
      }
    } else if (type == 'ambulance') {
      map['pickup_lat'] = pickupLat;
      map['pickup_lng'] = pickupLng;
      map['destination_lat'] = destinationLat;
      map['destination_lng'] = destinationLng;
      map['ambulance_type'] = ambulanceType;
      map['ambulance_reference_id'] = ambulanceReferenceId;
      map['ambulance_id'] = ambulanceId;
      map['patient_condition_notes'] = patientConditionNotes;
      map['pickup_address'] = pickupAddress;
      map['destination_hospital_id'] = destinationHospitalId;
      map['destination_address'] = destinationAddress;
      if (prescriptionAssetId != null) {
        map['prescription_asset_id'] = prescriptionAssetId;
      } else {
        map['prescription_document_id'] = prescriptionDocumentId;
      }
    } else if (type == 'blood') {
      map['blood_stock_id'] = bloodStockId;
      map['blood_type'] = bloodType;
      map['units_needed'] = unitsNeeded;
      map['hospital_id'] = hospitalId;
      map['hospital_name'] = hospitalName;
      map['prescribing_doctor'] = prescribingDoctor;
      if (prescriptionAssetId != null) {
        map['prescription_asset_id'] = prescriptionAssetId;
      } else {
        map['prescription_document_id'] = prescriptionDocumentId;
      }
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
    DateTime? confirmedAt,
    int? holdDurationMinutes,
    double? estimatedPrice,
    DateTime? createdAt,
    String? bedId,
    String? bedType,
    String? prescriptionDocumentId,
    String? prescriptionAssetId,
    String? prescriptionImageUrl,
    DateTime? admittedAt,
    DateTime? dischargedAt,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    String? ambulanceType,
    String? ambulanceReferenceId,
    String? ambulanceId,
    String? patientConditionNotes,
    String? pickupAddress,
    String? destinationHospitalId,
    String? destinationAddress,
    String? bloodStockId,
    String? bloodType,
    int? unitsNeeded,
    String? hospitalId,
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
      confirmedAt: confirmedAt ?? this.confirmedAt,
      holdDurationMinutes: holdDurationMinutes ?? this.holdDurationMinutes,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      createdAt: createdAt ?? this.createdAt,
      bedId: bedId ?? this.bedId,
      bedType: bedType ?? this.bedType,
      prescriptionDocumentId:
          prescriptionDocumentId ?? this.prescriptionDocumentId,
      prescriptionAssetId: prescriptionAssetId ?? this.prescriptionAssetId,
      prescriptionImageUrl: prescriptionImageUrl ?? this.prescriptionImageUrl,
      admittedAt: admittedAt ?? this.admittedAt,
      dischargedAt: dischargedAt ?? this.dischargedAt,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      ambulanceType: ambulanceType ?? this.ambulanceType,
      ambulanceReferenceId:
          ambulanceReferenceId ?? this.ambulanceReferenceId,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      patientConditionNotes:
          patientConditionNotes ?? this.patientConditionNotes,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationHospitalId:
          destinationHospitalId ?? this.destinationHospitalId,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      bloodStockId: bloodStockId ?? this.bloodStockId,
      bloodType: bloodType ?? this.bloodType,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      hospitalId: hospitalId ?? this.hospitalId,
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
