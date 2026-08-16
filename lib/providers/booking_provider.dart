import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/prescription_service.dart';
import '../shared/utils/lazy_expiry.dart';

class BookingProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<BookingRequestModel> _bookings = [];
  bool _isLoading = false;
  String? _error;

  List<BookingRequestModel> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<BookingRequestModel>> watchUserBookings(String userId) {
    return _firestoreService
        .streamCollection(
          'booking_requests',
          filters: [QueryFilter(field: 'user_id', isEqualTo: userId)],
        )
        .asyncMap(_bookingsFromSnapshot);
  }

  Stream<List<BookingRequestModel>> watchOrganizationBookings(
    String organizationId, {
    required String type,
  }) {
    return _firestoreService
        .streamCollection(
          'booking_requests',
          filters: [
            QueryFilter(field: 'organization_id', isEqualTo: organizationId),
            QueryFilter(field: 'type', isEqualTo: type),
          ],
        )
        .asyncMap(_bookingsFromSnapshot);
  }

  Stream<List<BookingRequestModel>> watchDiagnosticQueue(
    String organizationId,
  ) {
    return _firestoreService
        .streamCollection(
          'booking_requests',
          filters: [
            QueryFilter(field: 'organization_id', isEqualTo: organizationId),
            QueryFilter(field: 'type', isEqualTo: 'test'),
          ],
        )
        .map((snapshot) {
          final bookings = snapshot.docs
              .map(BookingRequestModel.tryFromFirestore)
              .whereType<BookingRequestModel>()
              .toList();
          bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return bookings;
        });
  }

  Stream<BookingRequestModel?> watchBooking(String bookingId) {
    return _firestoreService
        .streamDocument('booking_requests/$bookingId')
        .asyncMap((doc) async {
          if (!doc.exists) return null;
          var booking = BookingRequestModel.tryFromFirestore(doc);
          if (booking == null) return null;
          booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
          return booking;
        });
  }

  Future<List<BookingRequestModel>> _bookingsFromSnapshot(
    QuerySnapshot snapshot,
  ) async {
    final bookings = <BookingRequestModel>[];
    for (final doc in snapshot.docs) {
      var booking = BookingRequestModel.tryFromFirestore(doc);
      if (booking == null) continue;
      booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
      bookings.add(booking);
    }
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }

  Future<void> fetchUserBookings(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestoreService.getCollection(
        'booking_requests',
        filters: [QueryFilter(field: 'user_id', isEqualTo: userId)],
      );

      _bookings = [];
      for (final doc in snapshot.docs) {
        var booking = BookingRequestModel.tryFromFirestore(doc);
        if (booking == null) continue;
        booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
        _bookings.add(booking);
      }
      _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = 'Failed to load bookings: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchOrganizationBookings(String orgId, {String? type}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final filters = <QueryFilter>[
        QueryFilter(field: 'organization_id', isEqualTo: orgId),
      ];
      if (type != null) {
        filters.add(QueryFilter(field: 'type', isEqualTo: type));
      }

      final snapshot = await _firestoreService.getCollection(
        'booking_requests',
        filters: filters,
      );

      _bookings = [];
      for (final doc in snapshot.docs) {
        var booking = BookingRequestModel.tryFromFirestore(doc);
        if (booking == null) continue;
        booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
        _bookings.add(booking);
      }
      _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = 'Failed to load bookings: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllBookings({String? type}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final filters = <QueryFilter>[];
      if (type != null) {
        filters.add(QueryFilter(field: 'type', isEqualTo: type));
      }

      final snapshot = await _firestoreService.getCollection(
        'booking_requests',
        filters: filters.isEmpty ? null : filters,
      );

      _bookings = [];
      for (final doc in snapshot.docs) {
        var booking = BookingRequestModel.tryFromFirestore(doc);
        if (booking == null) continue;
        booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
        _bookings.add(booking);
      }
      _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = 'Failed to load bookings: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<BookingRequestModel?> getBooking(String bookingId) async {
    try {
      final doc = await _firestoreService.getDocument(
        'booking_requests/$bookingId',
      );
      if (doc.exists) {
        var booking = BookingRequestModel.tryFromFirestore(doc);
        if (booking == null) return null;
        booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
        return booking;
      }
    } catch (e) {
      _error = 'Failed to load booking: $e';
    }
    return null;
  }

  Future<String> createDiagnosticSerial({
    required String organizationId,
    required String organizationName,
    required String userId,
    required String patientName,
    required String contactNumber,
    required String testId,
  }) async {
    final now = DateTime.now();
    final queueDay = now.toUtc().add(const Duration(hours: 6));
    final queueDate = _queueDate(queueDay);
    final counterId = testId;
    final dailyCapacityId =
        '${queueDay.year}_${queueDay.month}_${queueDay.day}_$testId';
    final generatedBookingId = _firestoreService.generateId('booking_requests');

    try {
      return await _firestoreService.runTransaction((transaction) async {
        final testRef = _firestoreService.db.doc(
          'organizations/$organizationId/tests/$testId',
        );
        final counterRef = _firestoreService.db.doc(
          'organizations/$organizationId/test_queue_counters/$counterId',
        );
        final dailyCapacityRef = _firestoreService.db.doc(
          'organizations/$organizationId/test_daily_capacity/$dailyCapacityId',
        );
        final testSnapshot = await transaction.get(testRef);
        if (!testSnapshot.exists) {
          throw const BookingOperationException(
            'This diagnostic test is no longer available.',
          );
        }

        final counterSnapshot = await transaction.get(counterRef);
        final dailyCapacitySnapshot = await transaction.get(dailyCapacityRef);
        final counterData = counterSnapshot.data();
        final dailyCapacityData = dailyCapacitySnapshot.data();
        final testData = testSnapshot.data()!;
        final slotDurationMinutes =
            (testData['slot_duration_minutes'] as num?)?.toInt() ?? 15;
        if (slotDurationMinutes <= 0 || slotDurationMinutes > 240) {
          throw const BookingOperationException(
            'This test has an invalid queue slot duration.',
          );
        }
        final isAvailable = testData['is_available'] as bool? ?? true;
        final dailyCapacity =
            (testData['daily_capacity'] as num?)?.toInt() ?? 100;
        final usedToday = dailyCapacityData?['used'] as int? ?? 0;
        if (!isAvailable) {
          throw const BookingOperationException(
            'This diagnostic test is currently unavailable.',
          );
        }
        if (dailyCapacity <= 0 || usedToday >= dailyCapacity) {
          throw const BookingOperationException(
            'This diagnostic test is fully booked for today.',
          );
        }
        final serialNumber = (counterData?['last_serial'] as int? ?? 0) + 1;
        final lastEstimate =
            (counterData?['last_estimated_arrival'] as Timestamp?)?.toDate();
        final estimateBase = lastEstimate != null && lastEstimate.isAfter(now)
            ? lastEstimate
            : now;
        final estimatedArrival = estimateBase.add(
          Duration(minutes: slotDurationMinutes),
        );
        final bookingRef = _firestoreService.db.doc(
          'booking_requests/$generatedBookingId',
        );
        final booking = BookingRequestModel(
          id: generatedBookingId,
          type: 'test',
          organizationId: organizationId,
          organizationName: organizationName,
          userId: userId,
          patientName: patientName,
          contactNumber: contactNumber,
          status: 'pending',
          estimatedPrice: (testData['price'] as num? ?? 0).toDouble(),
          createdAt: now,
          testId: testId,
          testName: testData['test_name'] as String? ?? 'Diagnostic Test',
          serialNumber: serialNumber,
          queueDate: queueDate,
          queueYear: queueDay.year,
          queueMonth: queueDay.month,
          queueDay: queueDay.day,
          queueCounterId: counterId,
          estimatedArrivalTime: estimatedArrival,
        );

        transaction.set(counterRef, {
          'test_id': testId,
          'last_serial': serialNumber,
          'last_estimated_arrival': Timestamp.fromDate(estimatedArrival),
          'last_request_id': generatedBookingId,
          'last_called_serial': counterData?['last_called_serial'] ?? 0,
          'active_request_id': counterData?['active_request_id'],
          'last_queue_action_id': counterData?['last_queue_action_id'],
          'updated_at': Timestamp.fromDate(now),
        });
        transaction.set(dailyCapacityRef, {
          'test_id': testId,
          'queue_year': queueDay.year,
          'queue_month': queueDay.month,
          'queue_day': queueDay.day,
          'capacity': dailyCapacity,
          'used': usedToday + 1,
          'remaining': dailyCapacity - usedToday - 1,
          'last_request_id': generatedBookingId,
          'updated_at': Timestamp.fromDate(now),
        });
        final bookingData = booking.toFirestore();
        bookingData['created_at'] = FieldValue.serverTimestamp();
        transaction.set(bookingRef, bookingData);
        return generatedBookingId;
      });
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Unable to issue a diagnostic test serial.',
      );
      _error = message;
      notifyListeners();
      throw BookingOperationException(message);
    }
  }

  Future<void> callDiagnosticSerial(String bookingId) {
    return _updateDiagnosticSerial(
      bookingId: bookingId,
      expectedStatus: 'pending',
      nextStatus: 'confirmed',
      timestampField: 'called_at',
      errorMessage: 'Only a waiting serial can be called.',
    );
  }

  Future<void> completeDiagnosticSerial(String bookingId) {
    return _updateDiagnosticSerial(
      bookingId: bookingId,
      expectedStatus: 'confirmed',
      nextStatus: 'admitted',
      timestampField: 'completed_at',
      errorMessage: 'Only the called serial can be completed.',
    );
  }

  Future<void> cancelDiagnosticSerial(String bookingId) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        final bookingRef = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final snapshot = await transaction.get(bookingRef);
        if (!snapshot.exists) {
          validationError = 'This serial no longer exists.';
          return;
        }
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['type'] != 'test' ||
            (data['status'] != 'pending' && data['status'] != 'confirmed')) {
          validationError = 'Only waiting or called serials can be cancelled.';
          return;
        }
        final counterId = data['queue_counter_id'] as String?;
        final organizationId = data['organization_id'] as String?;
        if (counterId == null || organizationId == null) {
          validationError = 'This serial has invalid queue information.';
          return;
        }
        final counterRef = _firestoreService.db.doc(
          'organizations/$organizationId/test_queue_counters/$counterId',
        );
        final counterSnapshot = await transaction.get(counterRef);
        if (!counterSnapshot.exists) {
          validationError = 'The queue for this serial no longer exists.';
          return;
        }
        final counter = counterSnapshot.data()!;
        final serialNumber = data['serial_number'] as int?;
        final status = data['status'];
        final updates = <String, dynamic>{'last_queue_action_id': bookingId};
        if (status == 'pending') {
          if (counter['active_request_id'] != null ||
              serialNumber !=
                  (counter['last_called_serial'] as int? ?? 0) + 1) {
            validationError = 'Only the next waiting serial can be cancelled.';
            return;
          }
          updates['last_called_serial'] = serialNumber;
        } else if (counter['active_request_id'] == bookingId) {
          updates['active_request_id'] = null;
        } else {
          validationError = 'This serial is not the active queue entry.';
          return;
        }
        transaction.update(bookingRef, {'status': 'rejected'});
        transaction.update(counterRef, updates);
      });
      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Unable to cancel this serial.',
      );
      throw BookingOperationException(message);
    }
  }

  Future<void> _updateDiagnosticSerial({
    required String bookingId,
    required String expectedStatus,
    required String nextStatus,
    required String timestampField,
    required String errorMessage,
  }) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        final bookingRef = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final snapshot = await transaction.get(bookingRef);
        if (!snapshot.exists) {
          validationError = 'This serial no longer exists.';
          return;
        }
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['type'] != 'test' || data['status'] != expectedStatus) {
          validationError = errorMessage;
          return;
        }
        final counterId = data['queue_counter_id'] as String?;
        final organizationId = data['organization_id'] as String?;
        if (counterId == null || organizationId == null) {
          validationError = 'This serial has invalid queue information.';
          return;
        }
        final counterRef = _firestoreService.db.doc(
          'organizations/$organizationId/test_queue_counters/$counterId',
        );
        final counterSnapshot = await transaction.get(counterRef);
        if (!counterSnapshot.exists) {
          validationError = 'The queue for this serial no longer exists.';
          return;
        }
        final counter = counterSnapshot.data()!;
        final counterUpdates = <String, dynamic>{
          'last_queue_action_id': bookingId,
        };
        if (nextStatus == 'confirmed') {
          final expectedSerial =
              (counter['last_called_serial'] as int? ?? 0) + 1;
          if (counter['active_request_id'] != null ||
              data['serial_number'] != expectedSerial) {
            validationError =
                'Complete the active serial before calling the next patient.';
            return;
          }
          counterUpdates['active_request_id'] = bookingId;
          counterUpdates['last_called_serial'] = data['serial_number'];
        } else if (counter['active_request_id'] == bookingId) {
          counterUpdates['active_request_id'] = null;
        } else {
          validationError = 'This serial is not currently called.';
          return;
        }
        transaction.update(bookingRef, {
          'status': nextStatus,
          timestampField: FieldValue.serverTimestamp(),
        });
        transaction.update(counterRef, counterUpdates);
      });
      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }
    } catch (e) {
      final message = _operationError(e, fallback: errorMessage);
      throw BookingOperationException(message);
    }
  }

  String _queueDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> confirmBooking({
    required String bookingId,
    required String organizationId,
    required String resourceId,
    required String bookingType,
    required int holdMinutes,
  }) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        if (bookingType != 'bed' && bookingType != 'blood') {
          validationError = 'Unsupported inventory booking type.';
          return;
        }

        final isBed = bookingType == 'bed';
        final collection = isBed ? 'beds' : 'blood_stock';
        final referenceField = isBed ? 'bed_id' : 'blood_stock_id';
        final requestedTypeField = isBed ? 'bed_type' : 'blood_type';
        final resourceTypeField = isBed ? 'type' : 'blood_type';
        final heldField = isBed ? 'held_beds' : 'held_units';
        final totalField = isBed ? 'total_beds' : 'total_units';
        final usedField = isBed ? 'admitted_beds' : 'issued_units';
        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final resourceDoc = _firestoreService.db.doc(
          'organizations/$organizationId/$collection/$resourceId',
        );
        final bookingSnapshot = await transaction.get(bookingDoc);
        final resourceSnapshot = await transaction.get(resourceDoc);

        if (!bookingSnapshot.exists || !resourceSnapshot.exists) {
          validationError = 'The booking or requested resource no longer exists.';
          return;
        }

        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        final resourceData = resourceSnapshot.data() as Map<String, dynamic>;
        final storedResourceId = bookingData[referenceField] as String?;
        final requestedType = bookingData[requestedTypeField] as String?;
        final resourceType = resourceData[resourceTypeField] as String?;
        if (bookingData['status'] != 'pending') {
          validationError = 'This request has already been processed.';
          return;
        }
        if (bookingData['type'] != bookingType ||
            bookingData['organization_id'] != organizationId ||
            (storedResourceId != null && storedResourceId != resourceId) ||
            requestedType == null ||
            requestedType != resourceType) {
          validationError = 'The booking does not match this resource.';
          return;
        }

        final quantity = isBed ? 1 : bookingData['units_needed'] as int?;
        final currentHeld = resourceData[heldField] as int?;
        final total = resourceData[totalField] as int?;
        final used = resourceData[usedField] as int?;
        final effectiveHoldMinutes = isBed
            ? resourceData['hold_duration_minutes'] as int? ?? holdMinutes
            : holdMinutes;
        if (quantity == null ||
            quantity <= 0 ||
            currentHeld == null ||
            total == null ||
            used == null ||
            effectiveHoldMinutes <= 0 ||
            effectiveHoldMinutes > 1440) {
          validationError = 'The resource has invalid inventory settings.';
          return;
        }
        if (total - currentHeld - used < quantity) {
          validationError = 'Not enough resources are currently available.';
          return;
        }

        final heldUntil = DateTime.now().add(
          Duration(minutes: effectiveHoldMinutes),
        );
        transaction.update(resourceDoc, {
          heldField: currentHeld + quantity,
        });
        transaction.update(bookingDoc, {
          'status': 'confirmed',
          'held_until': Timestamp.fromDate(heldUntil),
          referenceField: resourceId,
        });
      });

      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }

      await _refreshBooking(bookingId);
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Failed to confirm booking.',
      );
      _error = message;
      notifyListeners();
      throw BookingOperationException(message);
    }
  }

  Future<String> createBookingWithPrescription(
    BookingRequestModel booking,
    Uint8List prescriptionBytes, {
    String contentType = 'image/jpeg',
  }) async {
    try {
      final id = booking.id.isEmpty ? generateBookingId() : booking.id;
      final newBooking = booking.copyWith(
        id: id,
        prescriptionDocumentId: id,
      );
      final bookingData = newBooking.toFirestore();
      bookingData['created_at'] = FieldValue.serverTimestamp();
      final prescriptionData = PrescriptionService.documentData(
        bookingId: id,
        userId: newBooking.userId,
        organizationId: newBooking.organizationId,
        bookingType: newBooking.type,
        data: prescriptionBytes,
        contentType: contentType,
      );

      final batch = _firestoreService.db.batch();
      batch.set(
        _firestoreService.db.doc('booking_requests/$id'),
        bookingData,
      );
      batch.set(
        _firestoreService.db.doc('prescription_documents/$id'),
        prescriptionData,
      );
      await batch.commit();

      _bookings.insert(0, newBooking);
      notifyListeners();
      return id;
    } catch (e) {
      _error = 'Failed to create booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  String generateBookingId() {
    return _firestoreService.generateId('booking_requests');
  }

  Future<void> confirmAmbulanceBooking({
    required String bookingId,
    required String organizationId,
    required String ambulanceId,
    int holdMinutes = 30,
  }) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        final ambulanceDoc = _firestoreService.db.doc(
          'organizations/$organizationId/ambulances/$ambulanceId',
        );
        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final ambulanceSnapshot = await transaction.get(ambulanceDoc);
        final bookingSnapshot = await transaction.get(bookingDoc);

        if (!ambulanceSnapshot.exists || !bookingSnapshot.exists) {
          validationError = 'The ambulance or booking no longer exists.';
          return;
        }

        final ambulanceData = ambulanceSnapshot.data() as Map<String, dynamic>;
        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        if (ambulanceData['status'] != 'available') {
          validationError =
              'This ambulance is no longer available. Refresh and try another vehicle.';
          return;
        }
        if (bookingData['status'] != 'pending') {
          validationError = 'This request has already been processed.';
          return;
        }
        if (bookingData['type'] != 'ambulance' ||
            bookingData['organization_id'] != organizationId ||
            bookingData['ambulance_type'] != ambulanceData['type'] ||
            bookingData['estimated_price'] != ambulanceData['base_fare'] ||
            holdMinutes <= 0 ||
            holdMinutes > 1440) {
          validationError = 'The booking does not match this ambulance.';
          return;
        }

        transaction.update(ambulanceDoc, {'status': 'busy'});
        transaction.update(bookingDoc, {
          'status': 'confirmed',
          'held_until': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: holdMinutes)),
          ),
          'ambulance_id': ambulanceId,
        });
      });

      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }

      await _refreshBooking(bookingId);
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Failed to confirm ambulance request.',
      );
      _error = message;
      notifyListeners();
      throw BookingOperationException(message);
    }
  }

  Future<void> completeAmbulanceBooking({
    required String bookingId,
    required String organizationId,
    required String ambulanceId,
  }) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        final ambulanceDoc = _firestoreService.db.doc(
          'organizations/$organizationId/ambulances/$ambulanceId',
        );
        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final ambulanceSnapshot = await transaction.get(ambulanceDoc);
        final bookingSnapshot = await transaction.get(bookingDoc);

        if (!ambulanceSnapshot.exists || !bookingSnapshot.exists) {
          validationError = 'The ambulance or booking no longer exists.';
          return;
        }

        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        final ambulanceData =
            ambulanceSnapshot.data() as Map<String, dynamic>;
        if (bookingData['status'] != 'confirmed') {
          validationError = 'Only confirmed trips can be completed.';
          return;
        }
        final heldUntil = bookingData['held_until'] as Timestamp?;
        if (heldUntil == null || !heldUntil.toDate().isAfter(DateTime.now())) {
          validationError = 'This ambulance reservation has expired.';
          return;
        }
        if (bookingData['type'] != 'ambulance' ||
            bookingData['organization_id'] != organizationId ||
            bookingData['ambulance_id'] != ambulanceId ||
            bookingData['ambulance_type'] != ambulanceData['type'] ||
            ambulanceData['status'] != 'busy') {
          validationError = 'The booking does not match this ambulance.';
          return;
        }

        transaction.update(ambulanceDoc, {'status': 'available'});
        transaction.update(bookingDoc, {
          'status': 'admitted',
          'held_until': null,
        });
      });

      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }

      await _refreshBooking(bookingId);
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Failed to complete ambulance trip.',
      );
      _error = message;
      notifyListeners();
      throw BookingOperationException(message);
    }
  }

  Future<void> admitBooking({
    required String bookingId,
    required String organizationId,
    required String resourceId,
    required String bookingType,
  }) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        if (bookingType != 'bed' && bookingType != 'blood') {
          validationError = 'Unsupported inventory booking type.';
          return;
        }

        final isBed = bookingType == 'bed';
        final collection = isBed ? 'beds' : 'blood_stock';
        final referenceField = isBed ? 'bed_id' : 'blood_stock_id';
        final requestedTypeField = isBed ? 'bed_type' : 'blood_type';
        final resourceTypeField = isBed ? 'type' : 'blood_type';
        final heldField = isBed ? 'held_beds' : 'held_units';
        final admittedField = isBed ? 'admitted_beds' : 'issued_units';
        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final resourceDoc = _firestoreService.db.doc(
          'organizations/$organizationId/$collection/$resourceId',
        );
        final bookingSnapshot = await transaction.get(bookingDoc);
        final resourceSnapshot = await transaction.get(resourceDoc);

        if (!bookingSnapshot.exists || !resourceSnapshot.exists) {
          validationError = 'The booking or requested resource no longer exists.';
          return;
        }

        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        final resourceData = resourceSnapshot.data() as Map<String, dynamic>;
        final storedResourceId = bookingData[referenceField] as String?;
        final requestedType = bookingData[requestedTypeField] as String?;
        final resourceType = resourceData[resourceTypeField] as String?;
        final heldUntil = bookingData['held_until'] as Timestamp?;
        if (bookingData['status'] != 'confirmed') {
          validationError = 'Only confirmed requests can be completed.';
          return;
        }
        if (heldUntil == null || !heldUntil.toDate().isAfter(DateTime.now())) {
          validationError = 'This reservation hold has expired.';
          return;
        }
        if (bookingData['type'] != bookingType ||
            bookingData['organization_id'] != organizationId ||
            (storedResourceId != null && storedResourceId != resourceId) ||
            requestedType == null ||
            requestedType != resourceType) {
          validationError = 'The booking does not match this resource.';
          return;
        }

        final quantity = isBed ? 1 : bookingData['units_needed'] as int?;
        final currentHeld = resourceData[heldField] as int?;
        final currentAdmitted = resourceData[admittedField] as int?;
        if (quantity == null ||
            quantity <= 0 ||
            currentHeld == null ||
            currentAdmitted == null ||
            currentHeld < quantity) {
          validationError = 'The held inventory no longer matches this request.';
          return;
        }

        transaction.update(resourceDoc, {
          heldField: currentHeld - quantity,
          admittedField: currentAdmitted + quantity,
        });
        transaction.update(bookingDoc, {
          'status': 'admitted',
          'held_until': null,
          referenceField: resourceId,
        });
      });

      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }

      await _refreshBooking(bookingId);
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Failed to complete booking.',
      );
      _error = message;
      notifyListeners();
      throw BookingOperationException(message);
    }
  }

  Future<void> rejectBooking(String bookingId) async {
    try {
      await _firestoreService.updateDocument('booking_requests/$bookingId', {
        'status': 'rejected',
      });
      await _refreshBooking(bookingId);
    } catch (e) {
      _error = 'Failed to reject booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearTerminalBookings() async {
    final terminal = _bookings.where((b) => b.isTerminal).toList();
    for (final booking in terminal) {
      final batch = _firestoreService.db.batch();
      if (booking.prescriptionDocumentId != null) {
        batch.delete(
          _firestoreService.db.doc(
            'prescription_documents/${booking.prescriptionDocumentId}',
          ),
        );
      }
      batch.delete(
        _firestoreService.db.doc('booking_requests/${booking.id}'),
      );
      await batch.commit();
    }
    _bookings.removeWhere((b) => b.isTerminal);
    notifyListeners();
  }

  Future<void> _refreshBooking(String bookingId) async {
    final doc = await _firestoreService.getDocument(
      'booking_requests/$bookingId',
    );
    if (doc.exists) {
      final updated = BookingRequestModel.tryFromFirestore(doc);
      if (updated == null) return;
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = updated;
      }
      notifyListeners();
    }
  }

  String _operationError(Object error, {required String fallback}) {
    if (error is BookingOperationException) return error.message;
    if (error is FirebaseException) {
      return error.message ?? '$fallback (${error.code})';
    }
    return fallback;
  }
}

class BookingOperationException implements Exception {
  final String message;

  const BookingOperationException(this.message);

  @override
  String toString() => message;
}
