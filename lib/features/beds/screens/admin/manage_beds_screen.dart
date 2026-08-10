import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/bed_type_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/availability_badge.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/bed_provider.dart';

class ManageBedsScreen extends StatefulWidget {
  const ManageBedsScreen({super.key});

  @override
  State<ManageBedsScreen> createState() => _ManageBedsScreenState();
}

class _ManageBedsScreenState extends State<ManageBedsScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgId = context.read<AuthProvider>().user?.organizationId;
    if (_orgId != null) {
      context.read<BedProvider>().fetchBedsForOrg(_orgId!);
    }
  }

  void _showBedForm({BedTypeModel? existing}) {
    showDialog(
      context: context,
      builder: (_) => _BedTypeFormDialog(
        existing: existing,
        onSave: (bed) async {
          await context.read<BedProvider>().saveBedType(_orgId!, bed);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) return const Center(child: Text('No organization assigned'));

    final bedProvider = context.watch<BedProvider>();
    final beds = bedProvider.getBedsForHospital(_orgId!);

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
                  Text('Manage Beds', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showBedForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bed Type'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (bedProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (beds.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No bed types configured')))
              else
                ...beds.map(
                  (bed) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _showBedForm(existing: bed),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bed.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _InfoChip('Total: ${bed.totalBeds}'),
                                    const SizedBox(width: 8),
                                    _InfoChip('Held: ${bed.heldBeds}'),
                                    const SizedBox(width: 8),
                                    _InfoChip('Admitted: ${bed.admittedBeds}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                PriceWidget(price: bed.pricePerDay, label: 'day', prominent: true),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              AvailabilityBadge(available: bed.availableBeds),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showBedForm(existing: bed)),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (dlgCtx) => AlertDialog(
                                          title: const Text('Delete Bed Type?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Cancel')),
                                            FilledButton(onPressed: () => Navigator.pop(dlgCtx, true), child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await context.read<BedProvider>().deleteBedType(_orgId!, bed.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                        ),
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

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
    );
  }
}

class _BedTypeFormDialog extends StatefulWidget {
  final BedTypeModel? existing;
  final Future<void> Function(BedTypeModel) onSave;

  const _BedTypeFormDialog({this.existing, required this.onSave});

  @override
  State<_BedTypeFormDialog> createState() => _BedTypeFormDialogState();
}

class _BedTypeFormDialogState extends State<_BedTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _totalController = TextEditingController();
  final _priceController = TextEditingController();
  final _holdController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? 'General';
    _totalController.text = widget.existing?.totalBeds.toString() ?? '';
    _priceController.text = widget.existing?.pricePerDay.toString() ?? '';
    _holdController.text = (widget.existing?.holdDurationMinutes ?? 30).toString();
  }

  @override
  void dispose() {
    _totalController.dispose();
    _priceController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Bed Type' : 'Add Bed Type'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Bed Type'),
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General')),
                DropdownMenuItem(value: 'ICU', child: Text('ICU')),
                DropdownMenuItem(value: 'NICU', child: Text('NICU')),
              ],
              onChanged: widget.existing != null ? null : (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalController,
              decoration: const InputDecoration(labelText: 'Total Beds'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.validatePositiveInt(v, 'Total beds'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price per Day (৳)', prefixText: '৳ '),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.validatePositiveNumber(v, 'Price'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holdController,
              decoration: const InputDecoration(labelText: 'Hold Duration (minutes)'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.validatePositiveInt(v, 'Hold duration'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isLoading = true);
                  try {
                    final bed = BedTypeModel(
                      id: widget.existing?.id ?? '',
                      organizationId: widget.existing?.organizationId ?? '',
                      type: _type,
                      totalBeds: int.parse(_totalController.text),
                      heldBeds: widget.existing?.heldBeds ?? 0,
                      admittedBeds: widget.existing?.admittedBeds ?? 0,
                      pricePerDay: double.parse(_priceController.text),
                      holdDurationMinutes: int.parse(_holdController.text),
                    );
                    await widget.onSave(bed);
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
