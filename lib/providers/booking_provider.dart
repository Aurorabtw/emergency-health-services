import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/booking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/prescription_api_service.dart';
import '../services/prescription_service.dart';
import '../services/server_clock_service.dart';
import '../shared/utils/lazy_expiry.dart';

class BookingProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ServerClockService _serverClock = ServerClockService();
  final PrescriptionApiService _prescriptionApi = PrescriptionApiService();

  List<BookingRequestModel> _bookings = [];
  bool _isLoading = false;
  String? _error;
  int _fetchGeneration = 0;

  static const int _terminalPageSize = 25;

  DocumentSnapshot? _terminalCursor;
  bool _hasMoreTerminal = false;
  bool _isLoadingMore = false;
  String? _historyScopeKey;

  List<BookingRequestModel> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreBookings => _hasMoreTerminal;
  bool get isLoadingMore => _isLoadingMore;

  Stream<List<BookingRequestModel>> watchUserBookings(String userId) {
    late StreamController<List<BookingRequestModel>> controller;
    StreamSubscription<List<BookingRequestModel>>? subscription;
    Timer? rolloverTimer;
    Timer? expiryTimer;

    Future<void> listenForCurrentDay({bool forceClockSync = false}) async {
      try {
        final serverNow = await _serverClock.now(forceRefresh: forceClockSync);
        if (controller.isClosed) return;
        await subscription?.cancel();
        subscription = _firestoreService
            .streamCollection(
              'booking_requests',
              filters: [QueryFilter(field: 'user_id', isEqualTo: userId)],
              orderBy: 'created_at',
              descending: true,
              limit: 50,
            )
            .asyncMap(_bookingsFromSnapshot)
            .listen((bookings) {
              controller.add(bookings);
              expiryTimer?.cancel();
              final delay = _untilNextHoldCheck(bookings);
              if (delay != null) {
                expiryTimer = Timer(
                  delay,
                  () => unawaited(listenForCurrentDay()),
                );
              }
            }, onError: controller.addError);
        rolloverTimer?.cancel();
        rolloverTimer = Timer(
          _untilNextDhakaDay(serverNow),
          () => unawaited(listenForCurrentDay(forceClockSync: true)),
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<BookingRequestModel>>(
      onListen: () => unawaited(listenForCurrentDay()),
      onCancel: () async {
        rolloverTimer?.cancel();
        expiryTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<BookingRequestModel>> watchOrganizationBookings(
    String organizationId, {
    required String type,
  }) {
    late StreamController<List<BookingRequestModel>> controller;
    StreamSubscription<List<BookingRequestModel>>? subscription;
    Timer? expiryTimer;

    void listenForExpiry() {
      subscription?.cancel();
      subscription = _firestoreService
          .streamCollection(
            'booking_requests',
            filters: [
              QueryFilter(field: 'organization_id', isEqualTo: organizationId),
              QueryFilter(field: 'type', isEqualTo: type),
            ],
          )
          .asyncMap(_bookingsFromSnapshot)
          .listen((bookings) {
            controller.add(bookings);
            expiryTimer?.cancel();
            final delay = _untilNextHoldCheck(bookings);
            if (delay != null) expiryTimer = Timer(delay, listenForExpiry);
          }, onError: controller.addError);
    }

    controller = StreamController<List<BookingRequestModel>>(
      onListen: listenForExpiry,
      onCancel: () async {
        expiryTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<BookingRequestModel>> watchDiagnosticQueue(
    String organizationId,
  ) {
    late StreamController<List<BookingRequestModel>> controller;
    StreamSubscription<List<BookingRequestModel>>? subscription;
    Timer? rolloverTimer;

    Future<void> listenForCurrentDay({bool forceClockSync = false}) async {
      try {
        final serverNow = await _serverClock.now(forceRefresh: forceClockSync);
        if (controller.isClosed) return;
        final queueDay = _dhakaTime(serverNow);
        await subscription?.cancel();
        if (controller.isClosed) return;
        subscription = _firestoreService
            .streamCollection(
              'booking_requests',
              filters: [
                QueryFilter(
                  field: 'organization_id',
                  isEqualTo: organizationId,
                ),
                QueryFilter(field: 'type', isEqualTo: 'test'),
                QueryFilter(field: 'queue_year', isEqualTo: queueDay.year),
                QueryFilter(field: 'queue_month', isEqualTo: queueDay.month),
                QueryFilter(field: 'queue_day', isEqualTo: queueDay.day),
              ],
            )
            .map((snapshot) {
              final bookings = snapshot.docs
                  .map(BookingRequestModel.tryFromFirestore)
                  .whereType<BookingRequestModel>()
                  .toList();
              bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return bookings;
            })
            .listen(controller.add, onError: controller.addError);

        rolloverTimer?.cancel();
        rolloverTimer = Timer(
          _untilNextDhakaDay(serverNow),
          () => unawaited(listenForCurrentDay(forceClockSync: true)),
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<BookingRequestModel>>(
      onListen: () => unawaited(listenForCurrentDay()),
      onCancel: () async {
        rolloverTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<BookingRequestModel?> watchBooking(String bookingId) {
    late StreamController<BookingRequestModel?> controller;
    StreamSubscription<BookingRequestModel?>? subscription;
    Timer? rolloverTimer;
    Timer? expiryTimer;

    Future<void> listenForCurrentDay({bool forceClockSync = false}) async {
      try {
        final serverNow = await _serverClock.now(forceRefresh: forceClockSync);
        if (controller.isClosed) return;
        await subscription?.cancel();
        subscription = _firestoreService
            .streamDocument('booking_requests/$bookingId')
            .asyncMap((doc) async {
              if (!doc.exists) return null;
              var booking = BookingRequestModel.tryFromFirestore(doc);
              if (booking == null) return null;
              booking = await LazyExpiry.checkAndExpire(
                booking,
                _firestoreService,
              );
              return booking;
            })
            .listen((booking) {
              controller.add(booking);
              expiryTimer?.cancel();
              final delay = booking == null
                  ? null
                  : _untilNextHoldCheck([booking]);
              if (delay != null) {
                expiryTimer = Timer(
                  delay,
                  () => unawaited(listenForCurrentDay()),
                );
              }
            }, onError: controller.addError);
        rolloverTimer?.cancel();
        rolloverTimer = Timer(
          _untilNextDhakaDay(serverNow),
          () => unawaited(listenForCurrentDay(forceClockSync: true)),
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<BookingRequestModel?>(
      onListen: () => unawaited(listenForCurrentDay()),
      onCancel: () async {
        rolloverTimer?.cancel();
        expiryTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
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
    await _loadBookingHistory(
      scopeKey: 'user|$userId',
      filters: [QueryFilter(field: 'user_id', isEqualTo: userId)],
    );
  }

  Future<void> fetchOrganizationBookings(String orgId, {String? type}) async {
    await _loadBookingHistory(
      scopeKey: 'org|$orgId|$type',
      filters: [
        QueryFilter(field: 'organization_id', isEqualTo: orgId),
        if (type != null) QueryFilter(field: 'type', isEqualTo: type),
      ],
      type: type,
    );
  }

  Future<void> fetchAllBookings({String? type}) async {
    await _loadBookingHistory(
      scopeKey: 'all|$type',
      filters: [
        if (type != null) QueryFilter(field: 'type', isEqualTo: type),
      ],
      type: type,
    );
  }

  Future<void> loadMoreBookings() async {
    if (!_hasMoreTerminal || _isLoadingMore || _historyScopeKey == null) {
      return;
    }
    final generation = ++_fetchGeneration;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final filters = _historyFiltersForScope(_historyScopeKey!);
      final page = await _fetchTerminalPage(
        filters: filters,
        type: _historyTypeForScope(_historyScopeKey!),
        startAfter: _terminalCursor,
      );
      if (generation != _fetchGeneration) return;
      final terminal = await _bookingsFromDocs(page.docs);
      final existingIds = {for (final b in _bookings) b.id};
      final merged = [..._bookings];
      for (final booking in terminal) {
        if (!existingIds.contains(booking.id)) merged.add(booking);
      }
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _bookings = merged;
      _terminalCursor = page.lastDocument;
      _hasMoreTerminal = page.hasMore;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = 'Failed to load more bookings: $e';
    }
    if (generation != _fetchGeneration) return;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> _loadBookingHistory({
    required String scopeKey,
    required List<QueryFilter> filters,
    String? type,
  }) async {
    final generation = ++_fetchGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final operational = await _fetchOperational(filters: filters, type: type);
      final terminalPage = await _fetchTerminalPage(
        filters: filters,
        type: type,
      );
      if (generation != _fetchGeneration) return;
      final terminal = await _bookingsFromDocs(terminalPage.docs);
      final merged = [...operational, ...terminal]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _bookings = merged;
      _historyScopeKey = scopeKey;
      _terminalCursor = terminalPage.lastDocument;
      _hasMoreTerminal = terminalPage.hasMore;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = 'Failed to load bookings: $e';
    }

    if (generation != _fetchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<BookingRequestModel>> _fetchOperational({
    required List<QueryFilter> filters,
    String? type,
  }) async {
    final statuses = type == 'bed'
        ? const ['pending', 'confirmed', 'admitted']
        : const ['pending', 'confirmed'];
    Query query = _firestoreService.db.collection('booking_requests');
    for (final filter in filters) {
      query = query.where(filter.field, isEqualTo: filter.isEqualTo);
    }
    final snapshot = await query
        .where('status', whereIn: statuses)
        .orderBy('created_at', descending: true)
        .get();
    return _bookingsFromSnapshot(snapshot);
  }

  Future<QueryPage> _fetchTerminalPage({
    required List<QueryFilter> filters,
    String? type,
    DocumentSnapshot? startAfter,
  }) async {
    final statuses = type == 'bed'
        ? const ['discharged', 'rejected', 'expired']
        : const ['admitted', 'discharged', 'rejected', 'expired'];
    Query query = _firestoreService.db.collection('booking_requests');
    for (final filter in filters) {
      query = query.where(filter.field, isEqualTo: filter.isEqualTo);
    }
    query = query
        .where('status', whereIn: statuses)
        .orderBy('created_at', descending: true);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snapshot = await query.limit(_terminalPageSize + 1).get();
    final hasMore = snapshot.docs.length > _terminalPageSize;
    final docs = snapshot.docs.take(_terminalPageSize).toList();
    return QueryPage(
      docs: docs,
      lastDocument: docs.isEmpty ? startAfter : docs.last,
      hasMore: hasMore,
    );
  }

  List<QueryFilter> _historyFiltersForScope(String scopeKey) {
    final parts = scopeKey.split('|');
    if (parts[0] == 'user') {
      return [QueryFilter(field: 'user_id', isEqualTo: parts[1])];
    }
    if (parts[0] == 'org') {
      return [
        QueryFilter(field: 'organization_id', isEqualTo: parts[1]),
        if (parts[2].isNotEmpty) QueryFilter(field: 'type', isEqualTo: parts[2]),
      ];
    }
    return [
      if (parts[1].isNotEmpty) QueryFilter(field: 'type', isEqualTo: parts[1]),
    ];
  }

  String? _historyTypeForScope(String scopeKey) {
    final parts = scopeKey.split('|');
    if (parts[0] == 'org') return parts[2].isEmpty ? null : parts[2];
    if (parts[0] == 'all') return parts[1].isEmpty ? null : parts[1];
    return null;
  }

  Future<List<BookingRequestModel>> _bookingsFromDocs(
    Iterable<QueryDocumentSnapshot> docs,
  ) async {
    final bookings = <BookingRequestModel>[];
    for (final doc in docs) {
      var booking = BookingRequestModel.tryFromFirestore(doc);
      if (booking == null) continue;
      booking = await LazyExpiry.checkAndExpire(booking, _firestoreService);
      bookings.add(booking);
    }
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
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
    try {
      return await _withDiagnosticClockRetry(
        (serverNow) => _createDiagnosticSerialOnce(
          organizationId: organizationId,
          organizationName: organizationName,
          userId: userId,
          patientName: patientName,
          contactNumber: contactNumber,
          testId: testId,
          serverNow: serverNow,
        ),
      );
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

  Future<String> _createDiagnosticSerialOnce({
    required String organizationId,
    required String organizationName,
    required String userId,
    required String patientName,
    required String contactNumber,
    required String testId,
    required DateTime serverNow,
  }) async {
    final now = serverNow;
    final normalizedContact = contactNumber.replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );
    final queueDay = _dhakaTime(now);
    final queueDate = _queueDate(queueDay);
    final dailyCapacityId =
        '${queueDay.year}_${queueDay.month}_${queueDay.day}_$testId';
    final counterId = testId;
    final userClaimId = '${organizationId}_$dailyCapacityId';
    final generatedBookingId = _firestoreService.generateId('booking_requests');

    final existingSerial = await _firestoreService.getCollection(
      'booking_requests',
      filters: [
        QueryFilter(field: 'user_id', isEqualTo: userId),
        QueryFilter(field: 'organization_id', isEqualTo: organizationId),
        QueryFilter(field: 'type', isEqualTo: 'test'),
        QueryFilter(field: 'test_id', isEqualTo: testId),
        QueryFilter(field: 'queue_year', isEqualTo: queueDay.year),
        QueryFilter(field: 'queue_month', isEqualTo: queueDay.month),
        QueryFilter(field: 'queue_day', isEqualTo: queueDay.day),
      ],
      limit: 1,
    );
    if (existingSerial.docs.isNotEmpty) {
      throw const BookingOperationException(
        'You already have a serial for this test today.',
      );
    }

    return _firestoreService.runTransaction((transaction) async {
      final testRef = _firestoreService.db.doc(
        'organizations/$organizationId/tests/$testId',
      );
      final counterRef = _firestoreService.db.doc(
        'organizations/$organizationId/test_queue_counters/$counterId',
      );
      final dailyCapacityRef = _firestoreService.db.doc(
        'organizations/$organizationId/test_daily_capacity/$dailyCapacityId',
      );
      final userClaimRef = _firestoreService.db.doc(
        'users/$userId/diagnostic_serial_claims/$userClaimId',
      );
      final testSnapshot = await transaction.get(testRef);
      if (!testSnapshot.exists) {
        throw const BookingOperationException(
          'This diagnostic test is no longer available.',
        );
      }

      final counterSnapshot = await transaction.get(counterRef);
      final dailyCapacitySnapshot = await transaction.get(dailyCapacityRef);
      final userClaimSnapshot = await transaction.get(userClaimRef);
      if (userClaimSnapshot.exists) {
        throw const BookingOperationException(
          'You already have a serial for this test today.',
        );
      }
      final counterData = counterSnapshot.data();
      final dailyCapacityData = dailyCapacitySnapshot.data();
      final testData = testSnapshot.data()!;
      final counterIsCurrent =
          counterSnapshot.exists && dailyCapacitySnapshot.exists;
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
      final serialNumber = counterIsCurrent
          ? (counterData?['last_serial'] as int? ?? 0) + 1
          : 1;
      final lastEstimate = counterIsCurrent
          ? (counterData?['last_estimated_arrival'] as Timestamp?)?.toDate()
          : null;
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
        contactNumber: normalizedContact,
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
        'queue_year': queueDay.year,
        'queue_month': queueDay.month,
        'queue_day': queueDay.day,
        'last_serial': serialNumber,
        'last_estimated_arrival': Timestamp.fromDate(estimatedArrival),
        'last_request_id': generatedBookingId,
        'last_called_serial': counterIsCurrent
            ? (counterData?['last_called_serial'] ?? 0)
            : 0,
        'active_request_id': counterIsCurrent
            ? (counterData?['active_request_id'])
            : null,
        'last_queue_action_id': counterIsCurrent
            ? (counterData?['last_queue_action_id'])
            : null,
        'updated_at': FieldValue.serverTimestamp(),
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
        'updated_at': FieldValue.serverTimestamp(),
      });
      final bookingData = booking.toFirestore();
      bookingData['created_at'] = FieldValue.serverTimestamp();
      transaction.set(bookingRef, bookingData);
      transaction.set(userClaimRef, {
        'organization_id': organizationId,
        'test_id': testId,
        'user_id': userId,
        'booking_id': generatedBookingId,
        'queue_year': queueDay.year,
        'queue_month': queueDay.month,
        'queue_day': queueDay.day,
        'created_at': FieldValue.serverTimestamp(),
      });
      return generatedBookingId;
    });
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
      await _withDiagnosticClockRetry(
        (serverNow) => _cancelDiagnosticSerialOnce(bookingId, serverNow),
      );
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Unable to cancel this serial.',
      );
      throw BookingOperationException(message);
    }
  }

  Future<void> _cancelDiagnosticSerialOnce(
    String bookingId,
    DateTime serverNow,
  ) async {
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
      if (!_isCurrentDiagnosticQueueDay(data, serverNow)) {
        validationError = 'Only today\'s diagnostic queue can be updated.';
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
            serialNumber != (counter['last_called_serial'] as int? ?? 0) + 1) {
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
  }

  Future<void> _updateDiagnosticSerial({
    required String bookingId,
    required String expectedStatus,
    required String nextStatus,
    required String timestampField,
    required String errorMessage,
  }) async {
    try {
      await _withDiagnosticClockRetry(
        (serverNow) => _updateDiagnosticSerialOnce(
          bookingId: bookingId,
          expectedStatus: expectedStatus,
          nextStatus: nextStatus,
          timestampField: timestampField,
          errorMessage: errorMessage,
          serverNow: serverNow,
        ),
      );
    } catch (e) {
      final message = _operationError(e, fallback: errorMessage);
      throw BookingOperationException(message);
    }
  }

  Future<void> _updateDiagnosticSerialOnce({
    required String bookingId,
    required String expectedStatus,
    required String nextStatus,
    required String timestampField,
    required String errorMessage,
    required DateTime serverNow,
  }) async {
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
      if (!_isCurrentDiagnosticQueueDay(data, serverNow)) {
        validationError = 'Only today\'s diagnostic queue can be updated.';
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
        final expectedSerial = (counter['last_called_serial'] as int? ?? 0) + 1;
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
  }

  String _queueDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _dhakaTime(DateTime serverTime) {
    return serverTime.toUtc().add(const Duration(hours: 6));
  }

  Duration _untilNextDhakaDay([DateTime? serverTime]) {
    final now = _dhakaTime(serverTime ?? _serverClock.correctedNow);
    final nextDay = DateTime.utc(now.year, now.month, now.day + 1);
    return nextDay.difference(now);
  }

  Duration? _untilNextHoldCheck(Iterable<BookingRequestModel> bookings) {
    DateTime? nearest;
    for (final booking in bookings) {
      final deadline = booking.isConfirmed ? booking.heldUntil : null;
      if (deadline != null && (nearest == null || deadline.isBefore(nearest))) {
        nearest = deadline;
      }
    }
    if (nearest == null) return null;
    final delay = nearest.difference(DateTime.now());
    return delay > Duration.zero ? delay + const Duration(seconds: 1) : null;
  }

  bool _isCurrentDiagnosticQueueDay(
    Map<String, dynamic> data,
    DateTime serverNow,
  ) {
    final queueDay = _dhakaTime(serverNow);
    return data['queue_year'] == queueDay.year &&
        data['queue_month'] == queueDay.month &&
        data['queue_day'] == queueDay.day;
  }

  Future<T> _withDiagnosticClockRetry<T>(
    Future<T> Function(DateTime serverNow) operation,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final serverNow = await _serverClock.now(forceRefresh: attempt > 0);
      try {
        return await operation(serverNow);
      } catch (error) {
        if (attempt > 0 || !_isRetryableDiagnosticClockError(error)) rethrow;
      }
    }
    throw StateError('The diagnostic operation retry did not complete.');
  }

  bool _isRetryableDiagnosticClockError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return true;
    }
    return error is BookingOperationException &&
        error.message == 'Only today\'s diagnostic queue can be updated.';
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
          validationError =
              'The booking or requested resource no longer exists.';
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

        transaction.update(resourceDoc, {heldField: currentHeld + quantity});
        transaction.update(bookingDoc, {
          'status': 'confirmed',
          'held_until': null,
          'confirmed_at': FieldValue.serverTimestamp(),
          'hold_duration_minutes': effectiveHoldMinutes,
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

      if (AppConfig.usePrescriptionApi) {
        // Cloudinary via the Vercel gateway. The gateway verifies the upload and
        // writes prescription_assets/{id}; we then create the booking, and the
        // Firestore rules bind the booking to that existing asset.
        final newBooking = booking.copyWith(id: id, prescriptionAssetId: id);
        await _prescriptionApi.upload(
          bookingId: id,
          organizationId: newBooking.organizationId,
          bookingType: newBooking.type,
          bytes: prescriptionBytes,
          contentType: contentType,
        );
        final bookingData = newBooking.toFirestore();
        bookingData['created_at'] = FieldValue.serverTimestamp();
        await _firestoreService.db.doc('booking_requests/$id').set(bookingData);

        _bookings.insert(0, newBooking);
        notifyListeners();
        return id;
      }

      // Legacy inline Firestore-blob flow: booking + prescription doc committed
      // atomically in one batch.
      final newBooking = booking.copyWith(id: id, prescriptionDocumentId: id);
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
      batch.set(_firestoreService.db.doc('booking_requests/$id'), bookingData);
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
          'held_until': null,
          'confirmed_at': FieldValue.serverTimestamp(),
          'hold_duration_minutes': holdMinutes,
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
        final ambulanceData = ambulanceSnapshot.data() as Map<String, dynamic>;
        if (bookingData['status'] != 'confirmed') {
          validationError = 'Only confirmed trips can be completed.';
          return;
        }
        final holdDeadline = _bookingHoldDeadline(bookingData);
        if (holdDeadline == null) {
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
          validationError =
              'The booking or requested resource no longer exists.';
          return;
        }

        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        final resourceData = resourceSnapshot.data() as Map<String, dynamic>;
        final storedResourceId = bookingData[referenceField] as String?;
        final requestedType = bookingData[requestedTypeField] as String?;
        final resourceType = resourceData[resourceTypeField] as String?;
        final holdDeadline = _bookingHoldDeadline(bookingData);
        if (bookingData['status'] != 'confirmed') {
          validationError = 'Only confirmed requests can be completed.';
          return;
        }
        if (holdDeadline == null) {
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
          validationError =
              'The held inventory no longer matches this request.';
          return;
        }

        transaction.update(resourceDoc, {
          heldField: currentHeld - quantity,
          admittedField: currentAdmitted + quantity,
        });
        final bookingUpdates = <String, dynamic>{
          'status': 'admitted',
          'held_until': null,
          referenceField: resourceId,
        };
        if (isBed) {
          bookingUpdates['admitted_at'] = FieldValue.serverTimestamp();
        }
        transaction.update(bookingDoc, bookingUpdates);
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

  Future<void> dischargeBedBooking({
    required String bookingId,
    required String organizationId,
    required String bedId,
  }) async {
    try {
      String? validationError;
      await _firestoreService.runTransaction((transaction) async {
        final bookingDoc = _firestoreService.db.doc(
          'booking_requests/$bookingId',
        );
        final bedDoc = _firestoreService.db.doc(
          'organizations/$organizationId/beds/$bedId',
        );
        final bookingSnapshot = await transaction.get(bookingDoc);
        final bedSnapshot = await transaction.get(bedDoc);
        if (!bookingSnapshot.exists || !bedSnapshot.exists) {
          validationError = 'The admission or bed no longer exists.';
          return;
        }

        final booking = bookingSnapshot.data() as Map<String, dynamic>;
        final bed = bedSnapshot.data() as Map<String, dynamic>;
        final admittedBeds = bed['admitted_beds'] as int?;
        if (booking['type'] != 'bed' ||
            booking['status'] != 'admitted' ||
            booking['organization_id'] != organizationId ||
            booking['bed_id'] != bedId ||
            admittedBeds == null ||
            admittedBeds <= 0) {
          validationError = 'This booking is not an active bed admission.';
          return;
        }

        transaction.update(bedDoc, {'admitted_beds': admittedBeds - 1});
        transaction.update(bookingDoc, {
          'status': 'discharged',
          'discharged_at': FieldValue.serverTimestamp(),
        });
      });
      if (validationError != null) {
        throw BookingOperationException(validationError!);
      }
      await _refreshBooking(bookingId);
    } catch (e) {
      final message = _operationError(
        e,
        fallback: 'Failed to discharge this patient.',
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
      // Cloudinary-hosted prescriptions are removed by the backend first
      // (best-effort) so deleting the booking does not orphan the image.
      if (booking.prescriptionAssetId != null && AppConfig.usePrescriptionApi) {
        try {
          await _prescriptionApi.delete(booking.id);
        } catch (_) {
          // Continue clearing even if remote cleanup fails.
        }
      }
      final batch = _firestoreService.db.batch();
      if (booking.prescriptionDocumentId != null &&
          booking.prescriptionAssetId == null) {
        batch.delete(
          _firestoreService.db.doc(
            'prescription_documents/${booking.prescriptionDocumentId}',
          ),
        );
      }
      batch.delete(_firestoreService.db.doc('booking_requests/${booking.id}'));
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

  DateTime? _bookingHoldDeadline(Map<String, dynamic> data) {
    final heldUntil = data['held_until'] as Timestamp?;
    if (heldUntil != null) return heldUntil.toDate();
    final confirmedAt = data['confirmed_at'] as Timestamp?;
    final durationMinutes = data['hold_duration_minutes'] as int?;
    if (confirmedAt == null || durationMinutes == null) return null;
    return confirmedAt.toDate().add(Duration(minutes: durationMinutes));
  }
}

class BookingOperationException implements Exception {
  final String message;

  const BookingOperationException(this.message);

  @override
  String toString() => message;
}
