import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/organization_model.dart';
import '../services/firestore_service.dart';
import '../services/server_clock_service.dart';

class OrganizationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ServerClockService _serverClock = ServerClockService();

  static const archiveLockTimeout = Duration(minutes: 15);

  List<OrganizationModel> _organizations = [];
  String? _loadedType;
  DateTime? _allOrganizationsLoadedAt;
  Future<void>? _allOrganizationsRequest;
  int _requestGeneration = 0;
  bool _isLoading = false;
  String? _error;

  List<OrganizationModel> get organizations => _organizations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OrganizationModel> getByType(String type) {
    return _organizations
        .where((o) => o.type == type && o.verified && o.isActive)
        .toList();
  }

  Future<void> fetchOrganizations({bool forceRefresh = false}) {
    final loadedAt = _allOrganizationsLoadedAt;
    if (!forceRefresh &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 5)) {
      return Future.value();
    }
    if (_allOrganizationsRequest != null) return _allOrganizationsRequest!;

    final request = _fetchOrganizations();
    _allOrganizationsRequest = request;
    return request.whenComplete(() => _allOrganizationsRequest = null);
  }

  Future<void> _fetchOrganizations() async {
    final generation = ++_requestGeneration;
    _isLoading = _organizations.isEmpty;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestoreService.getCollection('organizations');
      if (generation != _requestGeneration) return;
      _organizations = snapshot.docs
          .map((doc) => OrganizationModel.fromFirestore(doc))
          .toList();
      _loadedType = null;
      _allOrganizationsLoadedAt = DateTime.now();
    } catch (e) {
      if (generation != _requestGeneration) return;
      _error = 'Failed to load organizations: $e';
    }

    if (generation != _requestGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchVerifiedOrganizations({String? type}) async {
    final generation = ++_requestGeneration;
    // Stale-while-revalidate, but only when the cached list is the same type.
    // Switching tabs (e.g. hospitals → blood banks) must still show a skeleton
    // rather than briefly rendering the previous tab's organizations.
    if (_organizations.isEmpty || _loadedType != type) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final filters = <QueryFilter>[
        QueryFilter(field: 'verified', isEqualTo: true),
      ];
      if (type != null) {
        filters.add(QueryFilter(field: 'type', isEqualTo: type));
      }

      final snapshot = await _firestoreService.getCollection(
        'organizations',
        filters: filters,
      );
      if (generation != _requestGeneration) return;
      _organizations = snapshot.docs
          .map((doc) => OrganizationModel.fromFirestore(doc))
          .where((organization) => organization.isActive)
          .toList();
      _loadedType = type;
      _allOrganizationsLoadedAt = null;
    } catch (e) {
      if (generation != _requestGeneration) return;
      _error = 'Failed to load organizations: $e';
    }

    if (generation != _requestGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<OrganizationModel>> getVerifiedByType(String type) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        'organizations',
        filters: [
          QueryFilter(field: 'verified', isEqualTo: true),
          QueryFilter(field: 'type', isEqualTo: type),
        ],
      );
      return snapshot.docs
          .map((doc) => OrganizationModel.fromFirestore(doc))
          .where((organization) => organization.isActive)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<OrganizationModel?> getOrganization(String orgId) async {
    try {
      final doc = await _firestoreService.getDocument('organizations/$orgId');
      if (doc.exists) {
        return OrganizationModel.fromFirestore(doc);
      }
    } catch (e) {
      _error = 'Failed to load organization: $e';
    }
    return null;
  }

  Future<void> createOrganization(OrganizationModel org) async {
    try {
      _requestGeneration++;
      final id = _firestoreService.generateId('organizations');
      final newOrg = org.copyWith(id: id);
      await _firestoreService.setDocument(
        'organizations/$id',
        newOrg.toFirestore(),
      );
      _organizations.add(newOrg);
      if (_allOrganizationsLoadedAt != null) {
        _allOrganizationsLoadedAt = DateTime.now();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create organization: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateOrganization(OrganizationModel org) async {
    try {
      _requestGeneration++;
      await _firestoreService.updateDocument(
        'organizations/${org.id}',
        org.toFirestore(),
      );
      final index = _organizations.indexWhere((o) => o.id == org.id);
      if (index != -1) {
        _organizations[index] = org;
        if (_allOrganizationsLoadedAt != null) {
          _allOrganizationsLoadedAt = DateTime.now();
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update organization: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> archiveOrganization({
    required String orgId,
    required String archivedBy,
  }) async {
    var lockAcquired = false;
    try {
      _requestGeneration++;
      await _acquireArchiveLock(orgId, archivedBy);
      lockAcquired = true;
      await _refreshOrganization(orgId);
      notifyListeners();

      final blockers = await _findArchiveBlockers(orgId);
      if (blockers.isNotEmpty) {
        throw OrganizationArchiveException(blockers.join(' '));
      }

      await _firestoreService.updateDocument('organizations/$orgId', {
        'lifecycle_state': 'archived',
        'archived': true,
        'archived_at': FieldValue.serverTimestamp(),
        'archived_by': archivedBy,
        'archive_lock_at': null,
        'archive_lock_by': null,
        'verified': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      lockAcquired = false;
      await _refreshOrganization(orgId);
      if (_allOrganizationsLoadedAt != null) {
        _allOrganizationsLoadedAt = DateTime.now();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (lockAcquired) {
        try {
          await _cancelOwnedArchiveLock(orgId, archivedBy);
          await _refreshOrganization(orgId);
        } catch (_) {
          // A failed cleanup remains recoverable after the lock timeout.
        }
      }
      _error = 'Failed to archive organization: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelArchiveLock({
    required String orgId,
    required String cancelledBy,
  }) async {
    try {
      _requestGeneration++;
      final serverNow = await _serverClock.now(forceRefresh: true);
      final reference = _firestoreService.db.doc('organizations/$orgId');
      await _firestoreService.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          throw const OrganizationArchiveException(
            'This organization no longer exists.',
          );
        }
        final data = snapshot.data()!;
        if (_organizationState(data) != 'archiving') return;
        final lockBy = data['archive_lock_by'] as String?;
        final lockAt = (data['archive_lock_at'] as Timestamp?)?.toDate();
        final stale =
            lockAt != null &&
            !serverNow.isBefore(lockAt.add(archiveLockTimeout));
        if (lockBy != cancelledBy && !stale) {
          throw const OrganizationArchiveException(
            'Another administrator is archiving this organization. The lock can be cancelled after 15 minutes.',
          );
        }
        transaction.update(reference, {
          'lifecycle_state': 'active',
          'archived': false,
          'archive_lock_at': null,
          'archive_lock_by': null,
          'archived_at': null,
          'archived_by': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
      await _refreshOrganization(orgId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to cancel archive lock: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restoreOrganization(String orgId) async {
    try {
      _requestGeneration++;
      await _firestoreService.updateDocument('organizations/$orgId', {
        'lifecycle_state': 'active',
        'archived': false,
        'archive_lock_at': null,
        'archive_lock_by': null,
        'archived_at': null,
        'archived_by': null,
        'verified': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _refreshOrganization(orgId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to restore organization: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _acquireArchiveLock(String orgId, String archivedBy) async {
    final serverNow = await _serverClock.now(forceRefresh: true);
    final reference = _firestoreService.db.doc('organizations/$orgId');
    await _firestoreService.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw const OrganizationArchiveException(
          'This organization no longer exists.',
        );
      }
      final data = snapshot.data()!;
      final state = _organizationState(data);
      if (state == 'archived') {
        throw const OrganizationArchiveException(
          'This organization is already archived.',
        );
      }
      if (state == 'archiving') {
        final lockBy = data['archive_lock_by'] as String?;
        if (lockBy == archivedBy) return;
        final lockAt = (data['archive_lock_at'] as Timestamp?)?.toDate();
        final stale =
            lockAt != null &&
            !serverNow.isBefore(lockAt.add(archiveLockTimeout));
        if (!stale) {
          throw const OrganizationArchiveException(
            'Another administrator is already archiving this organization.',
          );
        }
      }

      transaction.update(reference, {
        'lifecycle_state': 'archiving',
        'archived': false,
        'archive_lock_at': FieldValue.serverTimestamp(),
        'archive_lock_by': archivedBy,
        'archived_at': null,
        'archived_by': null,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<String>> _findArchiveBlockers(String orgId) async {
    final users = _firestoreService.db
        .collection('users')
        .where('organization_id', isEqualTo: orgId)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    Future<QuerySnapshot<Map<String, dynamic>>> bookings(String status) {
      return _firestoreService.db
          .collection('booking_requests')
          .where('organization_id', isEqualTo: orgId)
          .where('status', isEqualTo: status)
          .limit(1)
          .get(const GetOptions(source: Source.server));
    }

    final admittedBeds = _firestoreService.db
        .collection('booking_requests')
        .where('organization_id', isEqualTo: orgId)
        .where('status', isEqualTo: 'admitted')
        .where('type', isEqualTo: 'bed')
        .limit(1)
        .get(const GetOptions(source: Source.server));
    final results = await Future.wait([
      users,
      bookings('pending'),
      bookings('confirmed'),
      admittedBeds,
    ]);

    return [
      if (results[0].docs.isNotEmpty)
        'Reassign or revoke all assigned administrators.',
      if (results[1].docs.isNotEmpty) 'Resolve all pending bookings.',
      if (results[2].docs.isNotEmpty) 'Resolve all confirmed bookings.',
      if (results[3].docs.isNotEmpty) 'Discharge all admitted bed patients.',
    ];
  }

  Future<void> _cancelOwnedArchiveLock(String orgId, String archivedBy) async {
    final reference = _firestoreService.db.doc('organizations/$orgId');
    await _firestoreService.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      if (_organizationState(data) != 'archiving' ||
          data['archive_lock_by'] != archivedBy) {
        return;
      }
      transaction.update(reference, {
        'lifecycle_state': 'active',
        'archived': false,
        'archive_lock_at': null,
        'archive_lock_by': null,
        'archived_at': null,
        'archived_by': null,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  String _organizationState(Map<String, dynamic> data) {
    final lifecycleState = data['lifecycle_state'] as String?;
    if (lifecycleState != null) return lifecycleState;
    return data['archived'] == true ? 'archived' : 'active';
  }

  Future<void> _refreshOrganization(String orgId) async {
    final doc = await _firestoreService.getDocument('organizations/$orgId');
    if (!doc.exists) return;
    final organization = OrganizationModel.fromFirestore(doc);
    final index = _organizations.indexWhere((item) => item.id == orgId);
    if (index == -1) {
      _organizations.add(organization);
    } else {
      _organizations[index] = organization;
    }
  }
}

class OrganizationArchiveException implements Exception {
  final String message;

  const OrganizationArchiveException(this.message);

  @override
  String toString() => message;
}
