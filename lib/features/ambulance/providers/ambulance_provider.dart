import 'package:flutter/material.dart';

import '../../../models/ambulance_model.dart';
import '../../../models/organization_model.dart';
import '../../../services/firestore_service.dart';

class AmbulanceProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<AmbulanceModel>> _orgAmbulances = {};
  bool _isLoading = false;
  String? _error;
  int _fetchGeneration = 0;

  Map<String, List<AmbulanceModel>> get orgAmbulances => _orgAmbulances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<AmbulanceModel> getAmbulancesForOrg(String orgId) => _orgAmbulances[orgId] ?? [];

  Future<void> fetchAmbulancesForOperators(List<OrganizationModel> operators) async {
    final generation = ++_fetchGeneration;
    // Stale-while-revalidate: only show a skeleton on the first load.
    if (_orgAmbulances.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final map = <String, List<AmbulanceModel>>{};
      for (var start = 0; start < operators.length; start += 8) {
        final end = (start + 8).clamp(0, operators.length);
        final results = await Future.wait(
          operators.sublist(start, end).map((operator) async {
            final snapshot = await _firestoreService.getCollection(
              'organizations/${operator.id}/ambulances',
              limit: 101,
            );
            if (snapshot.docs.length > 100) {
              throw StateError(
                '${operator.name} has more than 100 ambulances; use an organization-specific paged view.',
              );
            }
            return MapEntry(
              operator.id,
              snapshot.docs
                  .map(
                    (doc) => AmbulanceModel.fromFirestore(doc, operator.id),
                  )
                  .toList(),
            );
          }),
        );
        if (generation != _fetchGeneration) return;
        map.addEntries(results);
      }
      _orgAmbulances = map;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = 'Failed to load ambulances: $e';
    }

    if (generation != _fetchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<AmbulanceModel>> fetchAmbulancesForOrg(String orgId) async {
    final generation = ++_fetchGeneration;
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/ambulances');
      final ambulances = snapshot.docs.map((doc) => AmbulanceModel.fromFirestore(doc, orgId)).toList();
      if (generation != _fetchGeneration) return ambulances;
      _orgAmbulances[orgId] = ambulances;
      _isLoading = false;
      notifyListeners();
      return ambulances;
    } catch (e) {
      if (generation != _fetchGeneration) return [];
      _error = 'Failed to load ambulances: $e';
      _isLoading = false;
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
