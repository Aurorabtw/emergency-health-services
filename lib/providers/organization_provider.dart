import 'package:flutter/material.dart';

import '../models/organization_model.dart';
import '../services/firestore_service.dart';

class OrganizationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<OrganizationModel> _organizations = [];
  String? _loadedType;
  DateTime? _allOrganizationsLoadedAt;
  Future<void>? _allOrganizationsRequest;
  bool _isLoading = false;
  String? _error;

  List<OrganizationModel> get organizations => _organizations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OrganizationModel> getByType(String type) {
    return _organizations.where((o) => o.type == type && o.verified).toList();
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
    _isLoading = _organizations.isEmpty;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestoreService.getCollection('organizations');
      _organizations = snapshot.docs
          .map((doc) => OrganizationModel.fromFirestore(doc))
          .toList();
      _loadedType = null;
      _allOrganizationsLoadedAt = DateTime.now();
    } catch (e) {
      _error = 'Failed to load organizations: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchVerifiedOrganizations({String? type}) async {
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
      _organizations = snapshot.docs
          .map((doc) => OrganizationModel.fromFirestore(doc))
          .toList();
      _loadedType = type;
      _allOrganizationsLoadedAt = null;
    } catch (e) {
      _error = 'Failed to load organizations: $e';
    }

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
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create organization: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateOrganization(OrganizationModel org) async {
    try {
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
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update organization: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteOrganization(String orgId) async {
    try {
      await _firestoreService.deleteDocument('organizations/$orgId');
      _organizations.removeWhere((o) => o.id == orgId);
      if (_allOrganizationsLoadedAt != null) {
        _allOrganizationsLoadedAt = DateTime.now();
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete organization: $e';
      notifyListeners();
      rethrow;
    }
  }
}
