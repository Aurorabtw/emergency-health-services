import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/organization_model.dart';
import '../../../../models/user_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../services/firestore_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _loadError;
  String _roleFilter = 'all';
  int _page = 0;
  static const int _rowsPerPage = 10;
  DocumentSnapshot? _lastUserDocument;
  bool _hasMoreUsers = true;

  @override
  void initState() {
    super.initState();
    _watchUsers();
    context.read<OrganizationProvider>().fetchOrganizations();
  }

  Future<void> _watchUsers({bool reset = true}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        if (reset) {
          _users = [];
          _lastUserDocument = null;
          _hasMoreUsers = true;
          _page = 0;
        }
      });
    }
    try {
      final page = await _firestoreService.getCollectionPage(
        'users',
        orderBy: 'email',
        pageSize: 50,
        startAfter: reset ? null : _lastUserDocument,
      );
      if (!mounted) return;
      final loaded = page.docs.map(UserModel.fromFirestore);
      final usersById = {
        for (final user in _users) user.uid: user,
        for (final user in loaded) user.uid: user,
      };
      final users = usersById.values.toList()
        ..sort(
          (a, b) => (a.name ?? a.email).toLowerCase().compareTo(
            (b.name ?? b.email).toLowerCase(),
          ),
        );
      setState(() {
        _users = users;
        _lastUserDocument = page.lastDocument;
        _hasMoreUsers = page.hasMore;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load users: $error';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmAccessChange(UserModel user) {
    final restoring = user.accessRevoked;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(restoring ? 'Restore Platform Access' : 'Revoke Platform Access'),
        content: Text(
          restoring
              ? 'Restore access for "${user.name ?? user.email}" as a patient? Administrative roles must be assigned again.'
              : 'Revoke access for "${user.name ?? user.email}"? This signs them out and blocks protected platform access. Their Firebase Authentication account and booking history are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: restoring
                ? null
                : FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _setUserAccess(user, restore: restoring);
            },
            child: Text(restoring ? 'Restore Access' : 'Revoke Access'),
          ),
        ],
      ),
    );
  }

  Future<void> _setUserAccess(
    UserModel user, {
    required bool restore,
  }) async {
    try {
      final currentUserId = context.read<AuthProvider>().user?.uid;
      if (currentUserId == null || currentUserId == user.uid) return;
      final batch = _firestoreService.db.batch();
      final userRef = _firestoreService.db.doc('users/${user.uid}');
      final revocationRef = _firestoreService.db.doc(
        'access_revocations/${user.uid}',
      );
      batch.update(userRef, {
        'access_revoked': !restore,
        'access_revoked_at': restore ? null : FieldValue.serverTimestamp(),
        'access_revoked_by': restore ? null : currentUserId,
        'role': 'patient',
        'organization_id': null,
      });
      if (restore) {
        batch.delete(revocationRef);
      } else {
        batch.set(revocationRef, {
          'user_id': user.uid,
          'revoked_at': FieldValue.serverTimestamp(),
          'revoked_by': currentUserId,
        });
      }
      await batch.commit();
      await _watchUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restore
                ? 'Platform access was restored for ${user.name ?? user.email}.'
                : 'Platform access was revoked for ${user.name ?? user.email}.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'Permission denied. Deploy the updated Firestore rules before changing user access.'
          : e.message ?? 'Unable to change this user\'s access.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to change this user\'s access: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  List<OrganizationModel> _organizationsForRole(
    String role,
    List<OrganizationModel> organizations,
  ) {
    return organizations.where((organization) {
      if (organization.archived) return false;
      if (role == 'bed_admin' ||
          role == 'test_admin' ||
          role == 'hospital_admin') {
        return organization.type == 'hospital';
      }
      if (role == 'blood_bank_admin') {
        return organization.type == 'blood_bank';
      }
      if (role == 'ambulance_admin') {
        return organization.type == 'ambulance_operator';
      }
      return true;
    }).toList();
  }

  void _showRoleDialog(UserModel user) {
    if (user.accessRevoked) return;
    final orgProvider = context.read<OrganizationProvider>();
    String selectedRole = user.role;
    final compatibleOrganizations = _organizationsForRole(
      selectedRole,
      orgProvider.organizations,
    );
    String? selectedOrgId =
        compatibleOrganizations.any(
          (organization) => organization.id == user.organizationId,
        )
        ? user.organizationId
        : null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Role — ${user.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text('Patient')),
                  DropdownMenuItem(
                    value: 'bed_admin',
                    child: Text('Bed Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'test_admin',
                    child: Text('Diagnostic Test Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'blood_bank_admin',
                    child: Text('Blood Bank Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'ambulance_admin',
                    child: Text('Ambulance Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'hospital_admin',
                    child: Text('Hospital Admin (Temporary Legacy)'),
                  ),
                  DropdownMenuItem(
                    value: 'super_admin',
                    child: Text('Super Admin'),
                  ),
                ],
                onChanged: (v) => setDialogState(() {
                  selectedRole = v!;
                  selectedOrgId = null;
                }),
              ),
              if (selectedRole != 'patient' &&
                  selectedRole != 'super_admin') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedRole),
                  initialValue: selectedOrgId,
                  decoration: const InputDecoration(labelText: 'Organization'),
                  items:
                      _organizationsForRole(
                            selectedRole,
                            orgProvider.organizations,
                          )
                          .map(
                            (o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(o.name),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setDialogState(() => selectedOrgId = v),
                ),
              ],
              if (selectedRole == 'hospital_admin') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    'Temporary workaround for the old deployed Firestore rules. This role can manage both beds and tests; replace it after deploying the new rules.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  selectedRole != 'patient' &&
                      selectedRole != 'super_admin' &&
                      selectedOrgId == null
                  ? null
                  : () async {
                       await _firestoreService
                          .updateDocument('users/${user.uid}', {
                            'role': selectedRole,
                            'organization_id':
                                (selectedRole == 'patient' ||
                                    selectedRole == 'super_admin')
                                ? null
                                : selectedOrgId,
                           });
                       await _watchUsers();
                       if (context.mounted) Navigator.pop(dialogContext);
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
    final currentUserId = context.watch<AuthProvider>().user?.uid;
    final organizations = context.watch<OrganizationProvider>().organizations;
    final organizationNames = {
      for (final organization in organizations)
        organization.id: organization.name,
    };
    final organizationTypes = {
      for (final organization in organizations)
        organization.id: organization.type,
    };
    final query = _searchController.text.trim().toLowerCase();
    final filteredUsers = _users.where((user) {
      final matchesRole = _roleFilter == 'all' || user.role == _roleFilter;
      final organizationName = organizationNames[user.organizationId] ?? '';
      final matchesSearch =
          query.isEmpty ||
          (user.name ?? '').toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.roleLabel.toLowerCase().contains(query) ||
          organizationName.toLowerCase().contains(query);
      return matchesRole && matchesSearch;
    }).toList();
    final totalPages = filteredUsers.isEmpty
        ? 1
        : (filteredUsers.length / _rowsPerPage).ceil();
    final currentPage = _page.clamp(0, totalPages - 1);
    final start = currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, filteredUsers.length);
    final visibleUsers = filteredUsers.sublist(start, end);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'User Management',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            _CountBadge(count: _users.length),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage platform members, roles, and organization assignments. Search and counts cover loaded users.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh users',
                    onPressed: _isLoading ? null : _watchUsers,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 340,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search name, email, role, or hospital',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _page = 0);
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      onChanged: (_) => setState(() => _page = 0),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      initialValue: _roleFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All roles'),
                        ),
                        DropdownMenuItem(
                          value: 'patient',
                          child: Text('Patients'),
                        ),
                        DropdownMenuItem(
                          value: 'bed_admin',
                          child: Text('Bed Admins'),
                        ),
                        DropdownMenuItem(
                          value: 'test_admin',
                          child: Text('Test Admins'),
                        ),
                        DropdownMenuItem(
                          value: 'blood_bank_admin',
                          child: Text('Blood Bank Admins'),
                        ),
                        DropdownMenuItem(
                          value: 'ambulance_admin',
                          child: Text('Ambulance Admins'),
                        ),
                        DropdownMenuItem(
                          value: 'super_admin',
                          child: Text('Super Admins'),
                        ),
                        DropdownMenuItem(
                          value: 'hospital_admin',
                          child: Text('Legacy Hospital Admins'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _roleFilter = value;
                          _page = 0;
                        });
                      },
                    ),
                  ),
                  Text(
                    '${filteredUsers.length} result${filteredUsers.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_loadError != null)
                _UsersErrorState(message: _loadError!, onRetry: _watchUsers)
              else if (visibleUsers.isEmpty)
                const _EmptyUsersState()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Always use the card layout: it shows every field including
                    // the action buttons at any width, so nothing clips off the
                    // right edge like the wide table did.
                    if (constraints.maxWidth < 1600) {
                      return Column(
                        children: visibleUsers.map((user) {
                          return _MobileUserCard(
                            user: user,
                            organizationName:
                                organizationNames[user.organizationId],
                            organizationType:
                                organizationTypes[user.organizationId],
                            isCurrentUser: user.uid == currentUserId,
                            roleColor: _roleColor(user.role),
                            onEdit: () => _showRoleDialog(user),
                            onAccessChange: () => _confirmAccessChange(user),
                          );
                        }).toList(),
                      );
                    }

                    return _UsersTable(
                      users: visibleUsers,
                      organizationNames: organizationNames,
                      organizationTypes: organizationTypes,
                      currentUserId: currentUserId,
                      roleColor: _roleColor,
                      onEdit: _showRoleDialog,
                      onAccessChange: _confirmAccessChange,
                    );
                  },
                ),
              if (!_isLoading &&
                  _loadError == null &&
                  filteredUsers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PaginationBar(
                  start: start + 1,
                  end: end,
                  total: filteredUsers.length,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPrevious: currentPage == 0
                      ? null
                      : () => setState(() => _page = currentPage - 1),
                  onNext: currentPage >= totalPages - 1
                      ? null
                      : () => setState(() => _page = currentPage + 1),
                ),
                if (_hasMoreUsers) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _watchUsers(reset: false),
                      child: const Text('Load More Users'),
                    ),
                  ),
                ],
              ],
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
      case 'bed_admin':
        return Colors.blue.shade50;
      case 'test_admin':
        return Colors.purple.shade50;
      case 'blood_bank_admin':
        return Colors.red.shade50;
      case 'ambulance_admin':
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade50;
    }
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<UserModel> users;
  final Map<String, String> organizationNames;
  final Map<String, String> organizationTypes;
  final String? currentUserId;
  final Color Function(String) roleColor;
  final ValueChanged<UserModel> onEdit;
  final ValueChanged<UserModel> onAccessChange;

  const _UsersTable({
    required this.users,
    required this.organizationNames,
    required this.organizationTypes,
    required this.currentUserId,
    required this.roleColor,
    required this.onEdit,
    required this.onAccessChange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          horizontalMargin: 16,
          columnSpacing: 18,
          headingRowColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          columns: const [
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Role')),
            DataColumn(
              label: SizedBox(
                width: 190,
                child: Text('Assigned Hospital / Organization', maxLines: 2),
              ),
            ),
            DataColumn(label: Text('Profile')),
            DataColumn(label: Text('Actions')),
          ],
          rows: users.map((user) {
            final isCurrentUser = user.uid == currentUserId;
            final hasValidAssignment = _hasValidAssignment(
              user,
              organizationTypes[user.organizationId],
            );
            return DataRow(
              onSelectChanged: isCurrentUser || user.accessRevoked
                  ? null
                  : (_) => onEdit(user),
              cells: [
                DataCell(
                  Row(
                    children: [
                      _UserAvatar(user: user),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name?.trim().isNotEmpty == true
                                  ? user.name!
                                  : 'Unnamed user',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isCurrentUser)
                              Text(
                                'Your account',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(user.email, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  _RoleBadge(
                    label: user.roleLabel,
                    color: roleColor(user.role),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            organizationNames[user.organizationId] ??
                                'Not assigned',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: user.organizationId == null
                                  ? Colors.grey.shade500
                                  : null,
                            ),
                          ),
                        ),
                        if (!hasValidAssignment) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message:
                                'This role has an invalid organization assignment',
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ProfileBadge(isComplete: user.profileComplete),
                      _AccessBadge(isRevoked: user.accessRevoked),
                    ],
                  ),
                ),
                DataCell(
                  _UserActions(
                    isCurrentUser: isCurrentUser,
                    isRevoked: user.accessRevoked,
                    onEdit: () => onEdit(user),
                    onAccessChange: () => onAccessChange(user),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MobileUserCard extends StatelessWidget {
  final UserModel user;
  final String? organizationName;
  final String? organizationType;
  final bool isCurrentUser;
  final Color roleColor;
  final VoidCallback onEdit;
  final VoidCallback onAccessChange;

  const _MobileUserCard({
    required this.user,
    required this.organizationName,
    required this.organizationType,
    required this.isCurrentUser,
    required this.roleColor,
    required this.onEdit,
    required this.onAccessChange,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidAssignment = _hasValidAssignment(user, organizationType);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isCurrentUser || user.accessRevoked ? null : onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _UserAvatar(user: user),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name?.trim().isNotEmpty == true
                              ? user.name!
                              : 'Unnamed user',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          user.email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _UserActions(
                    isCurrentUser: isCurrentUser,
                    isRevoked: user.accessRevoked,
                    onEdit: onEdit,
                    onAccessChange: onAccessChange,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoleBadge(label: user.roleLabel, color: roleColor),
                  _ProfileBadge(isComplete: user.profileComplete),
                  _AccessBadge(isRevoked: user.accessRevoked),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Assigned Hospital / Organization',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 3),
              Text(
                organizationName ?? 'Not assigned',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (!hasValidAssignment) ...[
                const SizedBox(height: 6),
                Text(
                  'Invalid assignment - edit this user to select a compatible organization.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasValidAssignment(UserModel user, String? organizationType) {
  if (user.role == 'patient' || user.role == 'super_admin') {
    return user.organizationId == null;
  }
  if (user.organizationId == null || organizationType == null) return false;

  return switch (user.role) {
    'bed_admin' ||
    'test_admin' ||
    'hospital_admin' => organizationType == 'hospital',
    'blood_bank_admin' => organizationType == 'blood_bank',
    'ambulance_admin' => organizationType == 'ambulance_operator',
    _ => false,
  };
}

class _UserAvatar extends StatelessWidget {
  final UserModel user;

  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final source = user.name?.trim().isNotEmpty == true
        ? user.name!
        : user.email;
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        source.isEmpty ? '?' : source[0].toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final bool isComplete;

  const _ProfileBadge({required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color.shade600),
          const SizedBox(width: 6),
          Text(
            isComplete ? 'Complete' : 'Incomplete',
            style: TextStyle(
              color: color.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessBadge extends StatelessWidget {
  final bool isRevoked;

  const _AccessBadge({required this.isRevoked});

  @override
  Widget build(BuildContext context) {
    final color = isRevoked ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isRevoked ? 'Revoked' : 'Active',
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UserActions extends StatelessWidget {
  final bool isCurrentUser;
  final bool isRevoked;
  final VoidCallback onEdit;
  final VoidCallback onAccessChange;

  const _UserActions({
    required this.isCurrentUser,
    required this.isRevoked,
    required this.onEdit,
    required this.onAccessChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 19),
          tooltip: isCurrentUser
              ? 'You cannot change your own admin role'
              : 'Assign role',
          onPressed: isCurrentUser || isRevoked ? null : onEdit,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isRevoked ? Icons.lock_open_outlined : Icons.lock_outline,
            size: 19,
            color: isCurrentUser || isRevoked ? null : Colors.red.shade400,
          ),
          tooltip: isCurrentUser
              ? 'You cannot revoke your own platform access'
              : isRevoked
              ? 'Restore platform access'
              : 'Revoke platform access',
          onPressed: isCurrentUser ? null : onAccessChange,
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int start;
  final int end;
  final int total;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.start,
    required this.end,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start-$end of $total users',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        Text(
          'Page ${currentPage + 1} of $totalPages',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No users match these filters',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _UsersErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
