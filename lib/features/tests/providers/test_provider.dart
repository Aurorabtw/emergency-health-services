import 'package:flutter/material.dart';

import '../../../models/organization_model.dart';
import '../../../models/test_model.dart';
import '../../../services/firestore_service.dart';

class TestProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<DiagnosticTestModel>> _orgTests = {};
  List<TestSearchResult> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  Map<String, List<DiagnosticTestModel>> get orgTests => _orgTests;
  List<TestSearchResult> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<DiagnosticTestModel> getTestsForOrg(String orgId) => _orgTests[orgId] ?? [];

  Future<void> fetchTestsForOrganizations(List<OrganizationModel> orgs) async {
    // Stale-while-revalidate: only show a skeleton on the first load.
    if (_orgTests.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      // One collectionGroup query fetches every org's test catalogue in a
      // single round-trip, instead of one request per org.
      final orgIds = orgs.map((o) => o.id).toSet();
      final snapshot = await _firestoreService.getCollectionGroup('tests');
      final map = {for (final id in orgIds) id: <DiagnosticTestModel>[]};
      for (final doc in snapshot.docs) {
        final orgId = doc.reference.parent.parent?.id;
        if (orgId == null || !map.containsKey(orgId)) continue;
        map[orgId]!.add(DiagnosticTestModel.fromFirestore(doc, orgId));
      }
      _orgTests = map;
    } catch (e) {
      _error = 'Failed to load tests: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<DiagnosticTestModel>> fetchTestsForOrg(String orgId) async {
    try {
      final snapshot = await _firestoreService.getCollection('organizations/$orgId/tests');
      final tests = snapshot.docs.map((doc) => DiagnosticTestModel.fromFirestore(doc, orgId)).toList();
      _orgTests[orgId] = tests;
      notifyListeners();
      return tests;
    } catch (e) {
      _error = 'Failed to load tests: $e';
      notifyListeners();
      return [];
    }
  }

  void searchTests(String query, List<OrganizationModel> orgs) {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    final lowerQuery = query.toLowerCase();
    _searchResults = [];

    for (final org in orgs) {
      final tests = _orgTests[org.id] ?? [];
      for (final test in tests) {
        if (test.testName.toLowerCase().contains(lowerQuery)) {
          _searchResults.add(TestSearchResult(organization: org, test: test));
        }
      }
    }

    notifyListeners();
  }

  Future<void> saveTest(String orgId, DiagnosticTestModel test) async {
    try {
      if (test.id.isEmpty) {
        final id = _firestoreService.generateId('organizations/$orgId/tests');
        final newTest = test.copyWith(id: id);
        await _firestoreService.setDocument('organizations/$orgId/tests/$id', newTest.toFirestore());
      } else {
        await _firestoreService.setDocument('organizations/$orgId/tests/${test.id}', test.toFirestore());
      }
      await fetchTestsForOrg(orgId);
    } catch (e) {
      _error = 'Failed to save test: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTest(String orgId, String testId) async {
    try {
      await _firestoreService.deleteDocument('organizations/$orgId/tests/$testId');
      await fetchTestsForOrg(orgId);
    } catch (e) {
      _error = 'Failed to delete test: $e';
      notifyListeners();
      rethrow;
    }
  }
}

class TestSearchResult {
  final OrganizationModel organization;
  final DiagnosticTestModel test;

  TestSearchResult({required this.organization, required this.test});
}
