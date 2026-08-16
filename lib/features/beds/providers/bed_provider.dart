import 'package:flutter/material.dart';

import '../../../models/bed_type_model.dart';
import '../../../models/organization_model.dart';
import '../../../services/firestore_service.dart';

class BedProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<BedTypeModel>> _hospitalBeds = {};
  bool _isLoading = false;
  String? _error;
  int _fetchGeneration = 0;

  Map<String, List<BedTypeModel>> get hospitalBeds => _hospitalBeds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BedTypeModel> getBedsForHospital(String orgId) => _hospitalBeds[orgId] ?? [];

  Future<void> fetchBedsForHospitals(List<OrganizationModel> hospitals) async {
    final generation = ++_fetchGeneration;
    // Stale-while-revalidate: only show a skeleton on the first load. On
    // refresh, keep the cached data on screen and update it in place.
    if (_hospitalBeds.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final map = <String, List<BedTypeModel>>{};
      for (var start = 0; start < hospitals.length; start += 8) {
        final end = (start + 8).clamp(0, hospitals.length);
        final results = await Future.wait(
          hospitals.sublist(start, end).map((hospital) async {
            final snapshot = await _firestoreService.getCollection(
              'organizations/${hospital.id}/beds',
              limit: 20,
            );
            return MapEntry(
              hospital.id,
              snapshot.docs
                  .map((doc) => BedTypeModel.fromFirestore(doc, hospital.id))
                  .toList(),
            );
          }),
        );
        if (generation != _fetchGeneration) return;
        map.addEntries(results);
      }
      _hospitalBeds = map;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = 'Failed to load bed data: $e';
    }

    if (generation != _fetchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<BedTypeModel>> fetchBedsForOrg(String orgId) async {
    final generation = ++_fetchGeneration;
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/beds');
      final beds = snapshot.docs.map((doc) => BedTypeModel.fromFirestore(doc, orgId)).toList();
      if (generation != _fetchGeneration) return beds;
      _hospitalBeds[orgId] = beds;
      _isLoading = false;
      notifyListeners();
      return beds;
    } catch (e) {
      if (generation != _fetchGeneration) return [];
      _error = 'Failed to load beds: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<void> saveBedType(String orgId, BedTypeModel bed) async {
    try {
      if (bed.id.isEmpty) {
        final duplicate = await _firestoreService.getCollection(
          'organizations/$orgId/beds',
          filters: [QueryFilter(field: 'type', isEqualTo: bed.type)],
          limit: 1,
        );
        if (duplicate.docs.isNotEmpty) {
          throw StateError('${bed.type} beds are already configured.');
        }
        final id = _bedDocumentId(bed.type);
        final bedRef = _firestoreService.db.doc(
          'organizations/$orgId/beds/$id',
        );
        await _firestoreService.runTransaction((transaction) async {
          final current = await transaction.get(bedRef);
          if (current.exists) {
            throw StateError('${bed.type} beds are already configured.');
          }
          transaction.set(bedRef, bed.copyWith(id: id).toFirestore());
        });
      } else {
        final bedRef = _firestoreService.db.doc(
          'organizations/$orgId/beds/${bed.id}',
        );
        await _firestoreService.runTransaction((transaction) async {
          final current = await transaction.get(bedRef);
          if (!current.exists) throw StateError('This bed type no longer exists.');
          final data = current.data()!;
          final held = data['held_beds'] as int? ?? 0;
          final admitted = data['admitted_beds'] as int? ?? 0;
          if (data['type'] != bed.type) {
            throw StateError('The bed type cannot be changed.');
          }
          if (bed.totalBeds < held + admitted) {
            throw StateError(
              'Total beds cannot be below the $held held and $admitted admitted beds.',
            );
          }
          transaction.update(bedRef, {
            'total_beds': bed.totalBeds,
            'price_per_day': bed.pricePerDay,
            'hold_duration_minutes': bed.holdDurationMinutes,
          });
        });
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
      final bedRef = _firestoreService.db.doc(
        'organizations/$orgId/beds/$bedId',
      );
      await _firestoreService.runTransaction((transaction) async {
        final current = await transaction.get(bedRef);
        if (!current.exists) return;
        final data = current.data()!;
        if ((data['held_beds'] as int? ?? 0) != 0 ||
            (data['admitted_beds'] as int? ?? 0) != 0) {
          throw StateError(
            'Beds with held or admitted patients cannot be deleted.',
          );
        }
        transaction.delete(bedRef);
      });
      await fetchBedsForOrg(orgId);
    } catch (e) {
      _error = 'Failed to delete bed type: $e';
      notifyListeners();
      rethrow;
    }
  }

  String _bedDocumentId(String type) => switch (type) {
    'General' => 'general',
    'ICU' => 'icu',
    'NICU' => 'nicu',
    _ => throw ArgumentError('Unsupported bed type.'),
  };

  int getTotalAvailable(String orgId, {String? bedType}) {
    final beds = _hospitalBeds[orgId] ?? [];
    if (bedType != null) {
      return beds
          .where((bed) => bed.type == bedType)
          .fold(0, (sum, bed) => sum + bed.availableBeds);
    }
    return beds.fold(0, (sum, b) => sum + b.availableBeds);
  }
}
