import 'package:flutter/material.dart';

import '../../../models/organization_model.dart';
import '../../../models/test_model.dart';
import '../../../services/firestore_service.dart';

class TestProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, List<DiagnosticTestModel>> _orgTests = {};
  List<TestSearchResult> _searchResults = [];
  List<DiagnosticTestCatalogModel> _catalog = [];
  bool _isLoading = false;
  bool _catalogLoading = false;
  String? _error;
  int _fetchGeneration = 0;

  Map<String, List<DiagnosticTestModel>> get orgTests => _orgTests;
  List<TestSearchResult> get searchResults => _searchResults;
  List<DiagnosticTestCatalogModel> get catalog => _catalog;
  bool get isLoading => _isLoading;
  bool get catalogLoading => _catalogLoading;
  String? get error => _error;

  List<DiagnosticTestModel> getTestsForOrg(String orgId) =>
      _orgTests[orgId] ?? [];

  Future<void> fetchTestsForOrganizations(List<OrganizationModel> orgs) async {
    final generation = ++_fetchGeneration;
    // Stale-while-revalidate: only show a skeleton on the first load.
    if (_orgTests.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final map = <String, List<DiagnosticTestModel>>{};
      for (var start = 0; start < orgs.length; start += 8) {
        final end = (start + 8).clamp(0, orgs.length);
        final results = await Future.wait(
          orgs.sublist(start, end).map((organization) async {
            final snapshot = await _firestoreService.getCollection(
              'organizations/${organization.id}/tests',
              limit: 201,
            );
            if (snapshot.docs.length > 200) {
              throw StateError(
                '${organization.name} has more than 200 tests; use an organization-specific paged view.',
              );
            }
            return MapEntry(
              organization.id,
              snapshot.docs
                  .map(
                    (doc) => DiagnosticTestModel.fromFirestore(
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
      _orgTests = map;
    } catch (e) {
      if (generation != _fetchGeneration) return;
      _error = 'Failed to load tests: $e';
    }

    if (generation != _fetchGeneration) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCatalog() async {
    _catalogLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestoreService.getCollection(
        'diagnostic_test_catalog',
      );
      _catalog =
          snapshot.docs.map(DiagnosticTestCatalogModel.fromFirestore).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
    } catch (e) {
      _error = 'Failed to load diagnostic test catalog: $e';
    }
    _catalogLoading = false;
    notifyListeners();
  }

  Future<void> createCatalogTest(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    if (_catalog.any(
      (test) => test.normalizedName == trimmedName.toLowerCase(),
    )) {
      throw StateError('This diagnostic test is already listed.');
    }

    final id = _firestoreService.generateId('diagnostic_test_catalog');
    final test = DiagnosticTestCatalogModel(
      id: id,
      name: trimmedName,
      createdAt: DateTime.now(),
    );
    await _firestoreService.setDocument(
      'diagnostic_test_catalog/$id',
      test.toFirestore(),
    );
    await fetchCatalog();
  }

  Future<void> setCatalogTestActive(
    DiagnosticTestCatalogModel test,
    bool active,
  ) async {
    await _firestoreService.updateDocument(
      'diagnostic_test_catalog/${test.id}',
      {'active': active},
    );
    await fetchCatalog();
  }

  Future<void> deleteCatalogTest(DiagnosticTestCatalogModel test) async {
    await _firestoreService.deleteDocument(
      'diagnostic_test_catalog/${test.id}',
    );
    await fetchCatalog();
  }

  Future<void> ensureCatalogFromOfferings() async {
    if (_catalog.isNotEmpty) return;
    final names = <String, String>{};
    for (final tests in _orgTests.values) {
      for (final test in tests) {
        names.putIfAbsent(
          test.testName.trim().toLowerCase(),
          () => test.testName,
        );
      }
    }
    if (names.isEmpty) return;

    final batch = _firestoreService.db.batch();
    for (final name in names.values) {
      final reference = _firestoreService.db
          .collection('diagnostic_test_catalog')
          .doc();
      batch.set(
        reference,
        DiagnosticTestCatalogModel(
          id: reference.id,
          name: name,
          createdAt: DateTime.now(),
        ).toFirestore(),
      );
    }
    await batch.commit();
    await fetchCatalog();
  }

  Future<List<DiagnosticTestModel>> fetchTestsForOrg(String orgId) async {
    final generation = ++_fetchGeneration;
    try {
      final snapshot = await _firestoreService.getCollection(
        'organizations/$orgId/tests',
      );
      final tests = snapshot.docs
          .map((doc) => DiagnosticTestModel.fromFirestore(doc, orgId))
          .toList();
      if (generation != _fetchGeneration) return tests;
      _orgTests[orgId] = tests;
      _isLoading = false;
      notifyListeners();
      return tests;
    } catch (e) {
      if (generation != _fetchGeneration) return [];
      _error = 'Failed to load tests: $e';
      _isLoading = false;
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
      final duplicate = getTestsForOrg(orgId).any(
        (existing) =>
            existing.id != test.id &&
            ((test.catalogTestId != null &&
                    existing.catalogTestId == test.catalogTestId) ||
                existing.testName.trim().toLowerCase() ==
                    test.testName.trim().toLowerCase()),
      );
      if (duplicate) {
        throw StateError('This hospital already offers ${test.testName}.');
      }
      if (test.id.isEmpty) {
        final id = _firestoreService.generateId('organizations/$orgId/tests');
        final newTest = test.copyWith(id: id);
        await _firestoreService.setDocument(
          'organizations/$orgId/tests/$id',
          newTest.toFirestore(),
        );
      } else {
        await _firestoreService.setDocument(
          'organizations/$orgId/tests/${test.id}',
          test.toFirestore(),
        );
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
      await _firestoreService.deleteDocument(
        'organizations/$orgId/tests/$testId',
      );
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
