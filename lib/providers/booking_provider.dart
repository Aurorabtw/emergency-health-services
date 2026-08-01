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
      final doc = await _firestoreService.getDocument('booking_requests/$bookingId');
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
      await _firestoreService.setDocument('booking_requests/$id', newBooking.toFirestore());
      _bookings.insert(0, newBooking);
      notifyListeners();
      return id;
    } catch (e) {
      _error = 'Failed to create booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> confirmBooking(String bookingId, String resourcePath, String heldField, int holdMinutes) async {
    try {
      await _firestoreService.runTransaction((transaction) async {
        final resourceDoc = _firestoreService.db.doc(resourcePath);
        final resourceSnapshot = await transaction.get(resourceDoc);
        final data = resourceSnapshot.data() as Map<String, dynamic>;

        final currentHeld = data[heldField] ?? 0;
        final total = data['total_beds'] ?? data['total_units'] ?? data['total_vehicles'] ?? 0;
        final admitted = data['admitted_beds'] ?? data['issued_units'] ?? data['in_transit_vehicles'] ?? 0;
        final available = total - currentHeld - admitted;

        if (available <= 0) {
          throw Exception('No resources available');
        }

        final heldUntil = DateTime.now().add(Duration(minutes: holdMinutes));

        transaction.update(resourceDoc, {heldField: currentHeld + 1});

        final bookingDoc = _firestoreService.db.doc('booking_requests/$bookingId');
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

  Future<void> admitBooking(String bookingId, String resourcePath, String heldField, String admittedField) async {
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

        final bookingDoc = _firestoreService.db.doc('booking_requests/$bookingId');
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
    final doc = await _firestoreService.getDocument('booking_requests/$bookingId');
    if (doc.exists) {
      final updated = BookingRequestModel.fromFirestore(doc);
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = updated;
      }
      notifyListeners();
    }
  }
}
