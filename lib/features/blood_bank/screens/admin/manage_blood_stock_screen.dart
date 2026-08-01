import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/blood_stock_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/availability_badge.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/blood_provider.dart';

class ManageBloodStockScreen extends StatefulWidget {
  const ManageBloodStockScreen({super.key});

  @override
  State<ManageBloodStockScreen> createState() => _ManageBloodStockScreenState();
}

class _ManageBloodStockScreenState extends State<ManageBloodStockScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgId = context.read<AuthProvider>().user?.organizationId;
    if (_orgId != null) {
      context.read<BloodProvider>().fetchStockForOrg(_orgId!);
    }
  }

  void _showStockForm({BloodStockModel? existing}) {
    showDialog(
      context: context,
      builder: (_) => _BloodStockFormDialog(
        existing: existing,
        onSave: (stock) async {
          await context.read<BloodProvider>().saveBloodStock(_orgId!, stock);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) return const Center(child: Text('No organization assigned'));

    final bloodProvider = context.watch<BloodProvider>();
    final stock = bloodProvider.getStockForOrg(_orgId!);

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
                  Text('Manage Blood Stock', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showStockForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Blood Type'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (bloodProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (stock.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No blood stock configured')))
              else
                ...stock.map(
                  (s) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(s.bloodType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red.shade700)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('Total: ${s.totalUnits}  '),
                                  Text('Held: ${s.heldUnits}  '),
                                  Text('Issued: ${s.issuedUnits}'),
                                ]),
                                const SizedBox(height: 4),
                                PriceWidget(price: s.processingFeePerUnit, label: 'unit'),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              AvailabilityBadge(available: s.availableUnits, label: 'units'),
                              const SizedBox(height: 8),
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _showStockForm(existing: s)),
                            ],
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

class _BloodStockFormDialog extends StatefulWidget {
  final BloodStockModel? existing;
  final Future<void> Function(BloodStockModel) onSave;

  const _BloodStockFormDialog({this.existing, required this.onSave});

  @override
  State<_BloodStockFormDialog> createState() => _BloodStockFormDialogState();
}

class _BloodStockFormDialogState extends State<_BloodStockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _bloodType;
  final _totalController = TextEditingController();
  final _feeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bloodType = widget.existing?.bloodType ?? 'A+';
    _totalController.text = widget.existing?.totalUnits.toString() ?? '';
    _feeController.text = widget.existing?.processingFeePerUnit.toString() ?? '';
  }

  @override
  void dispose() {
    _totalController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Blood Stock' : 'Add Blood Type'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _bloodType,
              decoration: const InputDecoration(labelText: 'Blood Type'),
              items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: widget.existing != null ? null : (v) => setState(() => _bloodType = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalController,
              decoration: const InputDecoration(labelText: 'Total Units'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.validatePositiveInt(v, 'Total units'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feeController,
              decoration: const InputDecoration(labelText: 'Processing Fee per Unit (৳)', prefixText: '৳ '),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.validatePositiveNumber(v, 'Fee'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isLoading ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isLoading = true);
            try {
              final stock = BloodStockModel(
                id: widget.existing?.id ?? '',
                organizationId: widget.existing?.organizationId ?? '',
                bloodType: _bloodType,
                totalUnits: int.parse(_totalController.text),
                heldUnits: widget.existing?.heldUnits ?? 0,
                issuedUnits: widget.existing?.issuedUnits ?? 0,
                processingFeePerUnit: double.parse(_feeController.text),
                lastUpdated: DateTime.now(),
              );
              await widget.onSave(stock);
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
