import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/test_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/test_provider.dart';

class ManageTestsScreen extends StatefulWidget {
  const ManageTestsScreen({super.key});

  @override
  State<ManageTestsScreen> createState() => _ManageTestsScreenState();
}

class _ManageTestsScreenState extends State<ManageTestsScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgId = context.read<AuthProvider>().user?.organizationId;
    if (_orgId != null) {
      context.read<TestProvider>().fetchTestsForOrg(_orgId!);
    }
  }

  void _showForm({DiagnosticTestModel? existing}) {
    showDialog(
      context: context,
      builder: (_) => _TestFormDialog(
        existing: existing,
        onSave: (test) async {
          await context.read<TestProvider>().saveTest(_orgId!, test);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) return const Center(child: Text('No organization assigned'));

    final testProvider = context.watch<TestProvider>();
    final tests = testProvider.getTestsForOrg(_orgId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Manage Tests', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Add Test')),
                ],
              ),
              const SizedBox(height: 16),
              if (testProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (tests.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No tests configured')))
              else
                ...tests.map(
                  (test) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.science)),
                      title: Text(test.testName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          PriceWidget(price: test.price),
                          if (test.turnaroundTime.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.timer, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(test.turnaroundTime, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                          if (test.homeCollection) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.home, size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text('Home', style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(existing: test)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Test?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await context.read<TestProvider>().deleteTest(_orgId!, test.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestFormDialog extends StatefulWidget {
  final DiagnosticTestModel? existing;
  final Future<void> Function(DiagnosticTestModel) onSave;

  const _TestFormDialog({this.existing, required this.onSave});

  @override
  State<_TestFormDialog> createState() => _TestFormDialogState();
}

class _TestFormDialogState extends State<_TestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _turnaroundController = TextEditingController();
  final _surchargeController = TextEditingController();
  bool _homeCollection = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.testName ?? '';
    _priceController.text = widget.existing?.price.toString() ?? '';
    _turnaroundController.text = widget.existing?.turnaroundTime ?? '';
    _homeCollection = widget.existing?.homeCollection ?? false;
    _surchargeController.text = widget.existing?.homeCollectionSurcharge?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _turnaroundController.dispose();
    _surchargeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Test' : 'Add Test'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Test Name'),
                  validator: (v) => Validators.validateRequired(v, 'Test name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price (৳)', prefixText: '৳ '),
                  keyboardType: TextInputType.number,
                  validator: (v) => Validators.validatePositiveNumber(v, 'Price'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _turnaroundController,
                  decoration: const InputDecoration(labelText: 'Turnaround Time (e.g., "24 hours")'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Home Collection Available'),
                  value: _homeCollection,
                  onChanged: (v) => setState(() => _homeCollection = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_homeCollection)
                  TextFormField(
                    controller: _surchargeController,
                    decoration: const InputDecoration(labelText: 'Home Collection Surcharge (৳, optional)', prefixText: '৳ '),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isLoading ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isLoading = true);
            try {
              final test = DiagnosticTestModel(
                id: widget.existing?.id ?? '',
                organizationId: widget.existing?.organizationId ?? '',
                testName: _nameController.text.trim(),
                price: double.parse(_priceController.text),
                turnaroundTime: _turnaroundController.text.trim(),
                homeCollection: _homeCollection,
                homeCollectionSurcharge: _surchargeController.text.isNotEmpty ? double.parse(_surchargeController.text) : null,
              );
              await widget.onSave(test);
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
            if (mounted) setState(() => _isLoading = false);
          },
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
