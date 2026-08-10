import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_request_model.dart';
import '../services/firestore_service.dart';
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

  Stream<BookingRequestModel?> watchBooking(String bookingId) {
    return _firestoreService
        .streamDocument('booking_requests/$bookingId')
        .asyncMap((doc) async {
          if (!doc.exists) return null;
          var booking = BookingRequestModel.fromFirestore(doc);
          booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
          return booking;
        });
  }

  Future<List<BookingRequestModel>> _bookingsFromSnapshot(
    QuerySnapshot snapshot,
  ) async {
    final bookings = <BookingRequestModel>[];
    for (final doc in snapshot.docs) {
      var booking = BookingRequestModel.fromFirestore(doc);
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
        var booking = BookingRequestModel.fromFirestore(doc);
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
        var booking = BookingRequestModel.fromFirestore(doc);
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
        var booking = BookingRequestModel.fromFirestore(doc);
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
        var booking = BookingRequestModel.fromFirestore(doc);
        booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
        return booking;
      }
    } catch (e) {
      _error = 'Failed to load booking: $e';
    }
    return null;
  }

  Future<String> createBooking(BookingRequestModel booking) async {
    try {
      final id = _firestoreService.generateId('booking_requests');
      final newBooking = booking.copyWith(id: id);
      await _firestoreService.setDocument(
        'booking_requests/$id',
        newBooking.toFirestore(),
      );
      _bookings.insert(0, newBooking);
      notifyListeners();
      return id;
    } catch (e) {
      _error = 'Failed to create booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> confirmBooking(
    String bookingId,
    String resourcePath,
    String heldField,
    int holdMinutes,
  ) async {
    try {
      await _firestoreService.runTransaction((transaction) async {
        final resourceDoc = _firestoreService.db.doc(resourcePath);
        final resourceSnapshot = await transaction.get(resourceDoc);
        final data = resourceSnapshot.data() as Map<String, dynamic>;

        final currentHeld = data[heldField] ?? 0;
        final total =
            data['total_beds'] ??
            data['total_units'] ??
            data['total_vehicles'] ??
            0;
        final admitted =
            data['admitted_beds'] ??
            data['issued_units'] ??
            data['in_transit_vehicles'] ??
            0;
        final available = total - currentHeld - admitted;

        if (available <= 0) {
          throw Exception('No resources available');
        }

        final heldUntil = DateTime.now().add(Duration(minutes: holdMinutes));

        transaction.update(resourceDoc, {heldField: currentHeld + 1});

        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        transaction.update(bookingDoc, {
          'status': 'confirmed',
          'held_until': Timestamp.fromDate(heldUntil),
        });
      });

      await _refreshBooking(bookingId);
    } catch (e) {
      _error = 'Failed to confirm booking: $e';
      notifyListeners();
      rethrow;
    }
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
        if (bookingData['status'] != 'confirmed') {
          validationError = 'Only confirmed trips can be completed.';
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

  Future<void> admitBooking(
    String bookingId,
    String resourcePath,
    String heldField,
    String admittedField,
  ) async {
    try {
      await _firestoreService.runTransaction((transaction) async {
        final resourceDoc = _firestoreService.db.doc(resourcePath);
        final resourceSnapshot = await transaction.get(resourceDoc);
        final data = resourceSnapshot.data() as Map<String, dynamic>;

        final currentHeld = data[heldField] ?? 0;
        final currentAdmitted = data[admittedField] ?? 0;

        transaction.update(resourceDoc, {
          heldField: currentHeld > 0 ? currentHeld - 1 : 0,
          admittedField: currentAdmitted + 1,
        });

        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        transaction.update(bookingDoc, {'status': 'admitted'});
      });

      await _refreshBooking(bookingId);
    } catch (e) {
      _error = 'Failed to admit booking: $e';
      notifyListeners();
      rethrow;
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
      await _firestoreService.deleteDocument('booking_requests/${booking.id}');
    }
    _bookings.removeWhere((b) => b.isTerminal);
    notifyListeners();
  }

  Future<void> _refreshBooking(String bookingId) async {
    final doc = await _firestoreService.getDocument(
      'booking_requests/$bookingId',
    );
    if (doc.exists) {
      final updated = BookingRequestModel.fromFirestore(doc);
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
