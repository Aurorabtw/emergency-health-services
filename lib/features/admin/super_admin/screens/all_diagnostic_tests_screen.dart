import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/tests/providers/test_provider.dart';
import '../../../../models/test_model.dart';
import '../../../../providers/organization_provider.dart';

class AllDiagnosticTestsScreen extends StatefulWidget {
  const AllDiagnosticTestsScreen({super.key});

  @override
  State<AllDiagnosticTestsScreen> createState() =>
      _AllDiagnosticTestsScreenState();
}

class _AllDiagnosticTestsScreenState extends State<AllDiagnosticTestsScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final organizationProvider = context.read<OrganizationProvider>();
      final testProvider = context.read<TestProvider>();
      await organizationProvider.fetchOrganizations();
      if (!mounted) return;
      final hospitals = organizationProvider.organizations
          .where((organization) => organization.type == 'hospital')
          .toList();
      await testProvider.fetchTestsForOrganizations(hospitals);
      await testProvider.fetchCatalog();
      await testProvider.ensureCatalogFromOfferings();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Diagnostic Test'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a test name to the global catalog. Hospital diagnostic admins can then select it when creating an offering.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Test Name',
                    hintText: 'e.g., Lipid Profile',
                    errorText: error,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: saving
                      ? null
                      : (_) async {
                          await _saveCatalogTest(
                            dialogContext,
                            controller.text,
                            setDialogState,
                            (value) => error = value,
                            (value) => saving = value,
                          );
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () => _saveCatalogTest(
                      dialogContext,
                      controller.text,
                      setDialogState,
                      (value) => error = value,
                      (value) => saving = value,
                    ),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add Test'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _saveCatalogTest(
    BuildContext dialogContext,
    String name,
    StateSetter setDialogState,
    ValueChanged<String?> setError,
    ValueChanged<bool> setSaving,
  ) async {
    if (name.trim().isEmpty) {
      setDialogState(() => setError('Enter a test name'));
      return;
    }
    setDialogState(() {
      setError(null);
      setSaving(true);
    });
    try {
      await context.read<TestProvider>().createCatalogTest(name);
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    } catch (e) {
      if (dialogContext.mounted) {
        setDialogState(() {
          setError(e is StateError ? e.message : 'Unable to add test: $e');
          setSaving(false);
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final tests = provider.catalog
        .where((test) => test.name.toLowerCase().contains(query))
        .toList();
    final activeCount = provider.catalog.where((test) => test.active).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnostic Test Catalog',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${provider.catalog.length} tests • $activeCount available to hospital admins',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Test'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search master test list',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade50,
                    child: Text(_error!),
                  ),
                if (_isLoading || provider.catalogLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (tests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Text('No catalog tests found.'),
                    ),
                  )
                else
                  ...tests.map(
                    (test) => _CatalogTestCard(
                      test: test,
                      onActiveChanged: (active) async {
                        try {
                          await context
                              .read<TestProvider>()
                              .setCatalogTestActive(test, active);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unable to update test: $e'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogTestCard extends StatelessWidget {
  final DiagnosticTestCatalogModel test;
  final ValueChanged<bool> onActiveChanged;

  const _CatalogTestCard({required this.test, required this.onActiveChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        value: test.active,
        onChanged: onActiveChanged,
        secondary: CircleAvatar(
          backgroundColor: test.active
              ? Colors.purple.shade50
              : Colors.grey.shade200,
          child: Icon(
            Icons.science,
            color: test.active ? Colors.purple : Colors.grey,
          ),
        ),
        title: Text(
          test.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          test.active
              ? 'Available for hospital diagnostic admins'
              : 'Hidden from hospital diagnostic admins',
        ),
      ),
    );
  }
}
