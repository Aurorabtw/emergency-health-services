import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/blood_stock_model.dart';
import '../../../models/organization_model.dart';
import '../../../services/firestore_service.dart';

class BloodProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<BloodStockModel>> _orgBloodStock = {};
  bool _isLoading = false;
  String? _error;
  int _fetchGeneration = 0;

  Map<String, List<BloodStockModel>> get orgBloodStock => _orgBloodStock;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BloodStockModel> getStockForOrg(String orgId) => _orgBloodStock[orgId] ?? [];

  Future<void> fetchStockForOrganizations(List<OrganizationModel> orgs) async {
    final generation = ++_fetchGeneration;
    // Stale-while-revalidate: only show a skeleton on the first load.
    if (_orgBloodStock.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final map = <String, List<BloodStockModel>>{};
      for (var start = 0; start < orgs.length; start += 8) {
        final end = (start + 8).clamp(0, orgs.length);
        final results = await Future.wait(
          orgs.sublist(start, end).map((organization) async {
            final snapshot = await _firestoreService.getCollection(
              'organizations/${organization.id}/blood_stock',
              limit: 20,
            );
            return MapEntry(
              organization.id,
              snapshot.docs
                  .map(
                    (doc) => BloodStockModel.fromFirestore(
                      doc,
                      organization.id,
                    ),
                  )
                  .toList(),
            );
          }),
        );
        if (generation != _fetchGeneration) return;
        map.addEntries(results);
      }
      _orgBloodStock = map;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = 'Failed to load blood stock: $e';
    }

    if (generation != _fetchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<List<BloodStockModel>> fetchStockForOrg(String orgId) async {
    final generation = ++_fetchGeneration;
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/blood_stock');
      final stock = snapshot.docs.map((doc) => BloodStockModel.fromFirestore(doc, orgId)).toList();
      if (generation != _fetchGeneration) return stock;
      _orgBloodStock[orgId] = stock;
      _isLoading = false;
      notifyListeners();
      return stock;
    } catch (e) {
      if (generation != _fetchGeneration) return [];
      _error = 'Failed to load stock: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<void> saveBloodStock(String orgId, BloodStockModel stock) async {
    try {
      if (stock.id.isEmpty) {
        final duplicate = await _firestoreService.getCollection(
          'organizations/$orgId/blood_stock',
          filters: [
            QueryFilter(field: 'blood_type', isEqualTo: stock.bloodType),
          ],
          limit: 1,
        );
        if (duplicate.docs.isNotEmpty) {
          throw StateError('${stock.bloodType} stock is already configured.');
        }
        final id = _bloodDocumentId(stock.bloodType);
        final stockRef = _firestoreService.db.doc(
          'organizations/$orgId/blood_stock/$id',
        );
        await _firestoreService.runTransaction((transaction) async {
          final current = await transaction.get(stockRef);
          if (current.exists) {
            throw StateError('${stock.bloodType} stock is already configured.');
          }
          final data = stock.copyWith(id: id).toFirestore();
          data['last_updated'] = FieldValue.serverTimestamp();
          transaction.set(stockRef, data);
        });
      } else {
        final stockRef = _firestoreService.db.doc(
          'organizations/$orgId/blood_stock/${stock.id}',
        );
        await _firestoreService.runTransaction((transaction) async {
          final current = await transaction.get(stockRef);
          if (!current.exists) throw StateError('This blood stock no longer exists.');
          final data = current.data()!;
          final held = data['held_units'] as int? ?? 0;
          final issued = data['issued_units'] as int? ?? 0;
          if (data['blood_type'] != stock.bloodType) {
            throw StateError('The blood type cannot be changed.');
          }
          if (stock.totalUnits < held + issued) {
            throw StateError(
              'Total units cannot be below the $held held and $issued issued units.',
            );
          }
          transaction.update(stockRef, {
            'total_units': stock.totalUnits,
            'processing_fee_per_unit': stock.processingFeePerUnit,
            'last_updated': FieldValue.serverTimestamp(),
          });
        });
      }
      await fetchStockForOrg(orgId);
    } catch (e) {
      _error = 'Failed to save blood stock: $e';
      notifyListeners();
      rethrow;
    }
  }

  String _bloodDocumentId(String type) => switch (type) {
    'A+' => 'a_positive',
    'A-' => 'a_negative',
    'B+' => 'b_positive',
    'B-' => 'b_negative',
    'AB+' => 'ab_positive',
    'AB-' => 'ab_negative',
    'O+' => 'o_positive',
    'O-' => 'o_negative',
    _ => throw ArgumentError('Unsupported blood type.'),
  };

  int getAvailableUnits(String orgId, String bloodType) {
    final stock = _orgBloodStock[orgId] ?? [];
    return stock
        .where((item) => item.bloodType == bloodType)
        .fold(0, (total, item) => total + item.availableUnits);
  }
}
