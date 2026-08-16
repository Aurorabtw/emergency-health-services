import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServerClockService {
  static final ServerClockService _instance = ServerClockService._();

  factory ServerClockService() => _instance;

  ServerClockService._();

  static const _cacheLifetime = Duration(minutes: 5);

  Duration _offset = Duration.zero;
  DateTime? _synchronizedAt;
  String? _ownerId;
  Future<void>? _synchronizing;

  DateTime get correctedNow => DateTime.now().toUtc().add(_offset);

  Future<DateTime> now({bool forceRefresh = false}) async {
    final ownerId = FirebaseAuth.instance.currentUser?.uid;
    if (ownerId == null) {
      throw StateError(
        'An authenticated user is required to read server time.',
      );
    }

    final synchronizedAt = _synchronizedAt;
    final cacheIsFresh =
        _ownerId == ownerId &&
        synchronizedAt != null &&
        DateTime.now().toUtc().difference(synchronizedAt) < _cacheLifetime;
    if (!forceRefresh && cacheIsFresh) return correctedNow;

    try {
      await _synchronize(ownerId);
    } catch (_) {
      if (_ownerId != ownerId || _synchronizedAt == null) rethrow;
    }
    return correctedNow;
  }

  Future<void> _synchronize(String ownerId) async {
    final inFlight = _synchronizing;
    if (inFlight != null) {
      await inFlight;
      if (_ownerId != ownerId) await _synchronize(ownerId);
      return;
    }

    final synchronization = _synchronizeWithRetry(ownerId);
    _synchronizing = synchronization;
    try {
      await synchronization;
    } finally {
      if (identical(_synchronizing, synchronization)) {
        _synchronizing = null;
      }
    }
  }

  Future<void> _synchronizeWithRetry(String ownerId) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _probe(ownerId);
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<void> _probe(String ownerId) async {
    final reference = FirebaseFirestore.instance.doc(
      'server_clock_probes/$ownerId',
    );
    final sentAt = DateTime.now().toUtc();
    await reference.set({
      'owner_id': ownerId,
      'server_time': FieldValue.serverTimestamp(),
    });
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    final receivedAt = DateTime.now().toUtc();
    final serverTime = snapshot.data()?['server_time'] as Timestamp?;
    if (serverTime == null) {
      throw StateError('The Firestore server clock probe was unresolved.');
    }

    final midpoint = sentAt.add(
      Duration(microseconds: receivedAt.difference(sentAt).inMicroseconds ~/ 2),
    );
    _offset = serverTime.toDate().toUtc().difference(midpoint);
    _ownerId = ownerId;
    _synchronizedAt = receivedAt;
  }
}
