import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/user_model.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../services/firestore_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    context.read<OrganizationProvider>().fetchOrganizations();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestoreService.getCollection('users');
      setState(() {
        _users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove User'),
        content: Text('Are you sure you want to remove "${user.name ?? user.email}"? This will remove their profile from the platform.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.deleteDocument('users/${user.uid}');
              _loadUsers();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(UserModel user) {
    final orgProvider = context.read<OrganizationProvider>();
    String selectedRole = user.role;
    String? selectedOrgId = user.organizationId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Role — ${user.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text('Patient')),
                  DropdownMenuItem(value: 'hospital_admin', child: Text('Hospital Admin')),
                  DropdownMenuItem(value: 'blood_bank_admin', child: Text('Blood Bank Admin')),
                  DropdownMenuItem(value: 'ambulance_admin', child: Text('Ambulance Admin')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
              if (selectedRole != 'patient' && selectedRole != 'super_admin') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedOrgId,
                  decoration: const InputDecoration(labelText: 'Organization'),
                  items: orgProvider.organizations
                      .where((o) {
                        if (selectedRole == 'hospital_admin') return o.type == 'hospital';
                        if (selectedRole == 'blood_bank_admin') return o.type == 'blood_bank';
                        if (selectedRole == 'ambulance_admin') return o.type == 'ambulance_operator';
                        return true;
                      })
                      .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedOrgId = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await _firestoreService.updateDocument('users/${user.uid}', {
                  'role': selectedRole,
                  'organization_id': (selectedRole == 'patient' || selectedRole == 'super_admin') ? null : selectedOrgId,
                });
                if (context.mounted) Navigator.pop(dialogContext);
                _loadUsers();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage Users', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ..._users.map(
                  (user) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(user.email.isNotEmpty ? user.email[0].toUpperCase() : '?')),
                      title: Text(user.name ?? user.email),
                      subtitle: Text(user.email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(label: Text(user.role.replaceAll('_', ' ').toUpperCase()), backgroundColor: _roleColor(user.role)),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showRoleDialog(user)),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                            tooltip: 'Remove User',
                            onPressed: () => _confirmDeleteUser(user),
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

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple.shade50;
      case 'hospital_admin':
        return Colors.blue.shade50;
      case 'blood_bank_admin':
        return Colors.red.shade50;
      case 'ambulance_admin':
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade50;
    }
  }
}
