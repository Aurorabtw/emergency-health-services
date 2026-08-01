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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orgBloodStock = {};
      for (final org in orgs) {
        final snapshot = await _firestoreService.getCollection('organizations/${org.id}/blood_stock');
        _orgBloodStock[org.id] = snapshot.docs
            .map((doc) => BloodStockModel.fromFirestore(doc, org.id))
            .toList();
      }
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
