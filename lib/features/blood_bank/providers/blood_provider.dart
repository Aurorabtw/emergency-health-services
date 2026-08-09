import 'package:flutter/material.dart';

import '../../../models/blood_stock_model.dart';
import '../../../models/organization_model.dart';
import '../../../services/firestore_service.dart';

class BloodProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<BloodStockModel>> _orgBloodStock = {};
  bool _isLoading = false;
  String? _error;

  Map<String, List<BloodStockModel>> get orgBloodStock => _orgBloodStock;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BloodStockModel> getStockForOrg(String orgId) => _orgBloodStock[orgId] ?? [];

  Future<void> fetchStockForOrganizations(List<OrganizationModel> orgs) async {
    // Stale-while-revalidate: only show a skeleton on the first load.
    if (_orgBloodStock.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      // One collectionGroup query fetches every bank's stock in a single
      // round-trip, instead of one request per bank.
      final orgIds = orgs.map((o) => o.id).toSet();
      final snapshot = await _firestoreService.getCollectionGroup('blood_stock');
      final map = {for (final id in orgIds) id: <BloodStockModel>[]};
      for (final doc in snapshot.docs) {
        final orgId = doc.reference.parent.parent?.id;
        if (orgId == null || !map.containsKey(orgId)) continue;
        map[orgId]!.add(BloodStockModel.fromFirestore(doc, orgId));
      }
      _orgBloodStock = map;
    } catch (e) {
      _error = 'Failed to load blood stock: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<BloodStockModel>> fetchStockForOrg(String orgId) async {
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/blood_stock');
      final stock = snapshot.docs.map((doc) => BloodStockModel.fromFirestore(doc, orgId)).toList();
      _orgBloodStock[orgId] = stock;
      notifyListeners();
      return stock;
    } catch (e) {
      _error = 'Failed to load stock: $e';
      notifyListeners();
      return [];
    }
  }

  Future<void> saveBloodStock(String orgId, BloodStockModel stock) async {
    try {
      final path = 'organizations/$orgId/blood_stock/${stock.id}';
      if (stock.id.isEmpty) {
        final id = _firestoreService.generateId('organizations/$orgId/blood_stock');
        final newStock = stock.copyWith(id: id);
        await _firestoreService.setDocument('organizations/$orgId/blood_stock/$id', newStock.toFirestore());
      } else {
        await _firestoreService.setDocument(path, stock.toFirestore());
      }
      await fetchStockForOrg(orgId);
    } catch (e) {
      _error = 'Failed to save blood stock: $e';
      notifyListeners();
      rethrow;
    }
  }

  int getAvailableUnits(String orgId, String bloodType) {
    final stock = _orgBloodStock[orgId] ?? [];
    final match = stock.where((s) => s.bloodType == bloodType).firstOrNull;
    return match?.availableUnits ?? 0;
  }
}
