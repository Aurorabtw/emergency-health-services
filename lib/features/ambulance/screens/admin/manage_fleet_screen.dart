import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/ambulance_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/ambulance_provider.dart';

class ManageFleetScreen extends StatefulWidget {
  const ManageFleetScreen({super.key});

  @override
  State<ManageFleetScreen> createState() => _ManageFleetScreenState();
}

class _ManageFleetScreenState extends State<ManageFleetScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgId = context.read<AuthProvider>().user?.organizationId;
    if (_orgId != null) {
      context.read<AmbulanceProvider>().fetchAmbulancesForOrg(_orgId!);
    }
  }

  void _showForm({AmbulanceModel? existing}) {
    showDialog(
      context: context,
      builder: (_) => _AmbulanceFormDialog(
        existing: existing,
        onSave: (amb) async {
          await context.read<AmbulanceProvider>().saveAmbulance(_orgId!, amb);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) return const Center(child: Text('No organization assigned'));

    final ambProvider = context.watch<AmbulanceProvider>();
    final ambulances = ambProvider.getAmbulancesForOrg(_orgId!);

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
                  Text('Manage Fleet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Add Vehicle')),
                ],
              ),
              const SizedBox(height: 16),
              if (ambProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (ambulances.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No vehicles configured')))
              else
                ...ambulances.map(
                  (amb) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: amb.isAvailable ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.emergency, color: amb.isAvailable ? Colors.green : Colors.grey, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(amb.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                PriceWidget(price: amb.baseFare, label: 'base'),
                                if (amb.perKmRate != null) Text('+ ৳${amb.perKmRate!.toStringAsFixed(0)}/km', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: amb.isAvailable,
                                onChanged: (_) => context.read<AmbulanceProvider>().toggleStatus(_orgId!, amb),
                              ),
                              Text(amb.isAvailable ? 'Available' : 'Busy', style: TextStyle(fontSize: 12, color: amb.isAvailable ? Colors.green : Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(existing: amb)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Vehicle?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await context.read<AmbulanceProvider>().deleteAmbulance(_orgId!, amb.id);
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

class _AmbulanceFormDialog extends StatefulWidget {
  final AmbulanceModel? existing;
  final Future<void> Function(AmbulanceModel) onSave;

  const _AmbulanceFormDialog({this.existing, required this.onSave});

  @override
  State<_AmbulanceFormDialog> createState() => _AmbulanceFormDialogState();
}

class _AmbulanceFormDialogState extends State<_AmbulanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _fareController = TextEditingController();
  final _perKmController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? 'Basic';
    _fareController.text = widget.existing?.baseFare.toString() ?? '';
    _perKmController.text = widget.existing?.perKmRate?.toString() ?? '';
  }

  @override
  void dispose() {
    _fareController.dispose();
    _perKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Vehicle' : 'Add Vehicle'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Vehicle Type'),
              items: const [
                DropdownMenuItem(value: 'Basic', child: Text('Basic')),
                DropdownMenuItem(value: 'AC', child: Text('AC')),
                DropdownMenuItem(value: 'ICU', child: Text('ICU')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fareController,
              decoration: const InputDecoration(labelText: 'Base Fare (৳)', prefixText: '৳ '),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.validatePositiveNumber(v, 'Base fare'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _perKmController,
              decoration: const InputDecoration(labelText: 'Per-km Rate (৳, optional)', prefixText: '৳ '),
              keyboardType: TextInputType.number,
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
              final amb = AmbulanceModel(
                id: widget.existing?.id ?? '',
                organizationId: widget.existing?.organizationId ?? '',
                type: _type,
                status: widget.existing?.status ?? 'available',
                baseFare: double.parse(_fareController.text),
                perKmRate: _perKmController.text.isNotEmpty ? double.parse(_perKmController.text) : null,
              );
              await widget.onSave(amb);
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
