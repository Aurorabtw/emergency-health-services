import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/organization_model.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/utils/validators.dart';

class ManageOrganizationsScreen extends StatefulWidget {
  final String? typeFilter;

  const ManageOrganizationsScreen({super.key, this.typeFilter});

  @override
  State<ManageOrganizationsScreen> createState() =>
      _ManageOrganizationsScreenState();
}

class _ManageOrganizationsScreenState extends State<ManageOrganizationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().fetchOrganizations();
  }

  void _confirmDeleteOrg(OrganizationModel org) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Organization'),
        content: Text(
          'Are you sure you want to remove "${org.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<OrganizationProvider>().deleteOrganization(
                org.id,
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _OrganizationFormDialog(
        onSave: (org) async {
          await context.read<OrganizationProvider>().createOrganization(org);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final organizations = widget.typeFilter == null
        ? orgProvider.organizations
        : orgProvider.organizations
              .where((org) => org.type == widget.typeFilter)
              .toList();
    final pageTitle = switch (widget.typeFilter) {
      'hospital' => 'Hospitals',
      'blood_bank' => 'Blood Banks',
      'ambulance_operator' => 'Ambulance Operators',
      _ => 'All Organizations',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
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
                          pageTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${organizations.length} organization${organizations.length == 1 ? '' : 's'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Organization'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OrganizationFilterChip(
                    label: 'All',
                    selected: widget.typeFilter == null,
                    onSelected: () => context.go('/super-admin/organizations'),
                  ),
                  _OrganizationFilterChip(
                    label: 'Hospitals',
                    selected: widget.typeFilter == 'hospital',
                    onSelected: () =>
                        context.go('/super-admin/organizations?type=hospital'),
                  ),
                  _OrganizationFilterChip(
                    label: 'Blood Banks',
                    selected: widget.typeFilter == 'blood_bank',
                    onSelected: () => context.go(
                      '/super-admin/organizations?type=blood_bank',
                    ),
                  ),
                  _OrganizationFilterChip(
                    label: 'Ambulance Operators',
                    selected: widget.typeFilter == 'ambulance_operator',
                    onSelected: () => context.go(
                      '/super-admin/organizations?type=ambulance_operator',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (orgProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (organizations.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      widget.typeFilter == null
                          ? 'No organizations yet'
                          : 'No $pageTitle found',
                    ),
                  ),
                )
              else
                ...organizations.map(
                  (org) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: org.verified
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        child: Icon(
                          _orgIcon(org.type),
                          color: org.verified ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(
                        org.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${_orgTypeLabel(org.type)} - ${org.address}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!org.verified)
                            TextButton(
                              onPressed: () async {
                                await context
                                    .read<OrganizationProvider>()
                                    .updateOrganization(
                                      org.copyWith(verified: true),
                                    );
                              },
                              child: const Text('Verify'),
                            ),
                          Chip(
                            label: Text(org.verified ? 'Verified' : 'Pending'),
                            backgroundColor: org.verified
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            side: BorderSide(
                              color: org.verified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                            ),
                            tooltip: 'Remove Organization',
                            onPressed: () => _confirmDeleteOrg(org),
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

  IconData _orgIcon(String type) {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'blood_bank':
        return Icons.bloodtype;
      case 'ambulance_operator':
        return Icons.emergency;
      default:
        return Icons.business;
    }
  }

  String _orgTypeLabel(String type) {
    switch (type) {
      case 'hospital':
        return 'Hospital';
      case 'blood_bank':
        return 'Blood Bank';
      case 'ambulance_operator':
        return 'Ambulance Operator';
      default:
        return type;
    }
  }
}

class _OrganizationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _OrganizationFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _OrganizationFormDialog extends StatefulWidget {
  final Future<void> Function(OrganizationModel) onSave;

  const _OrganizationFormDialog({required this.onSave});

  @override
  State<_OrganizationFormDialog> createState() =>
      _OrganizationFormDialogState();
}

class _OrganizationFormDialogState extends State<_OrganizationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _type = 'hospital';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final org = OrganizationModel(
        id: '',
        type: _type,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: double.tryParse(_latController.text) ?? 0,
        longitude: double.tryParse(_lngController.text) ?? 0,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        verified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.onSave(org);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Organization'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Organization Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'hospital',
                      child: Text('Hospital'),
                    ),
                    DropdownMenuItem(
                      value: 'blood_bank',
                      child: Text('Blood Bank'),
                    ),
                    DropdownMenuItem(
                      value: 'ambulance_operator',
                      child: Text('Ambulance Operator'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Name',
                  ),
                  validator: (v) => Validators.validateRequired(v, 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: (v) => Validators.validateRequired(v, 'Address'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Latitude'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Longitude'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: Validators.validatePhone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
