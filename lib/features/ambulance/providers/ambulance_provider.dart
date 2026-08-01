import 'package:flutter/material.dart';

import '../../../models/ambulance_model.dart';
import '../../../models/organization_model.dart';
import '../../../services/firestore_service.dart';

class AmbulanceProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<AmbulanceModel>> _orgAmbulances = {};
  bool _isLoading = false;
  String? _error;

  Map<String, List<AmbulanceModel>> get orgAmbulances => _orgAmbulances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<AmbulanceModel> getAmbulancesForOrg(String orgId) => _orgAmbulances[orgId] ?? [];

  Future<void> fetchAmbulancesForOperators(List<OrganizationModel> operators) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orgAmbulances = {};
      for (final op in operators) {
        final snapshot = await _firestoreService.getCollection('organizations/${op.id}/ambulances');
        _orgAmbulances[op.id] = snapshot.docs
            .map((doc) => AmbulanceModel.fromFirestore(doc, op.id))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to load ambulances: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<AmbulanceModel>> fetchAmbulancesForOrg(String orgId) async {
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/ambulances');
      final ambulances = snapshot.docs.map((doc) => AmbulanceModel.fromFirestore(doc, orgId)).toList();
      _orgAmbulances[orgId] = ambulances;
      notifyListeners();
      return ambulances;
    } catch (e) {
      _error = 'Failed to load ambulances: $e';
      notifyListeners();
      return [];
    }
  }

  Future<void> saveAmbulance(String orgId, AmbulanceModel ambulance) async {
    try {
      if (ambulance.id.isEmpty) {
        final id = _firestoreService.generateId('organizations/$orgId/ambulances');
        final newAmb = ambulance.copyWith(id: id);
        await _firestoreService.setDocument('organizations/$orgId/ambulances/$id', newAmb.toFirestore());
      } else {
        await _firestoreService.setDocument('organizations/$orgId/ambulances/${ambulance.id}', ambulance.toFirestore());
      }
      await fetchAmbulancesForOrg(orgId);
    } catch (e) {
      _error = 'Failed to save ambulance: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAmbulance(String orgId, String ambulanceId) async {
    try {
      await _firestoreService.deleteDocument('organizations/$orgId/ambulances/$ambulanceId');
      await fetchAmbulancesForOrg(orgId);
    } catch (e) {
      _error = 'Failed to delete ambulance: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleStatus(String orgId, AmbulanceModel ambulance) async {
    final newStatus = ambulance.status == 'available' ? 'busy' : 'available';
    await saveAmbulance(orgId, ambulance.copyWith(status: newStatus));
  }

  int getAvailableCount(String orgId) {
    final ambulances = _orgAmbulances[orgId] ?? [];
    return ambulances.where((a) => a.isAvailable).length;
  }
}
