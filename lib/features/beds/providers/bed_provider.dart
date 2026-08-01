import 'package:flutter/material.dart';

import '../../../models/bed_type_model.dart';
import '../../../models/organization_model.dart';
import '../../../services/firestore_service.dart';

class BedProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<BedTypeModel>> _hospitalBeds = {};
  bool _isLoading = false;
  String? _error;

  Map<String, List<BedTypeModel>> get hospitalBeds => _hospitalBeds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BedTypeModel> getBedsForHospital(String orgId) => _hospitalBeds[orgId] ?? [];

  Future<void> fetchBedsForHospitals(List<OrganizationModel> hospitals) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _hospitalBeds = {};
      for (final hospital in hospitals) {
        final snapshot = await _firestoreService.getCollection(
          'organizations/${hospital.id}/beds',
        );
        _hospitalBeds[hospital.id] = snapshot.docs
            .map((doc) => BedTypeModel.fromFirestore(doc, hospital.id))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to load bed data: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<BedTypeModel>> fetchBedsForOrg(String orgId) async {
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/beds');
      final beds = snapshot.docs.map((doc) => BedTypeModel.fromFirestore(doc, orgId)).toList();
      _hospitalBeds[orgId] = beds;
      notifyListeners();
      return beds;
    } catch (e) {
      _error = 'Failed to load beds: $e';
      notifyListeners();
      return [];
    }
  }

  Future<void> saveBedType(String orgId, BedTypeModel bed) async {
    try {
      final path = 'organizations/$orgId/beds/${bed.id}';
      if (bed.id.isEmpty) {
        final id = _firestoreService.generateId('organizations/$orgId/beds');
        final newBed = bed.copyWith(id: id);
        await _firestoreService.setDocument('organizations/$orgId/beds/$id', newBed.toFirestore());
      } else {
        await _firestoreService.setDocument(path, bed.toFirestore());
      }
      await fetchBedsForOrg(orgId);
    } catch (e) {
      _error = 'Failed to save bed type: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBedType(String orgId, String bedId) async {
    try {
      await _firestoreService.deleteDocument('organizations/$orgId/beds/$bedId');
      await fetchBedsForOrg(orgId);
    } catch (e) {
      _error = 'Failed to delete bed type: $e';
      notifyListeners();
      rethrow;
    }
  }

  int getTotalAvailable(String orgId, {String? bedType}) {
    final beds = _hospitalBeds[orgId] ?? [];
    if (bedType != null) {
      final bed = beds.where((b) => b.type == bedType).firstOrNull;
      return bed?.availableBeds ?? 0;
    }
    return beds.fold(0, (sum, b) => sum + b.availableBeds);
  }
}
