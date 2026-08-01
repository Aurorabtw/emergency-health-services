import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/organization_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/organization_provider.dart';

class OrgAdminDashboard extends StatefulWidget {
  const OrgAdminDashboard({super.key});

  @override
  State<OrgAdminDashboard> createState() => _OrgAdminDashboardState();
}

class _OrgAdminDashboardState extends State<OrgAdminDashboard> {
  OrganizationModel? _org;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    final orgId = context.read<AuthProvider>().user?.organizationId;
    if (orgId != null) {
      final org = await context.read<OrganizationProvider>().getOrganization(orgId);
      if (mounted) setState(() { _org = org; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_org == null) {
      return const Center(child: Text('No organization assigned. Contact the platform administrator.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Organization: ${_org!.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  if (auth.isHospitalAdmin) ...[
                    _AdminActionCard(
                      title: 'Manage Beds',
                      description: 'Update bed types, counts, and pricing',
                      icon: Icons.bed,
                      onTap: () => context.go('/admin/beds'),
                    ),
                    _AdminActionCard(
                      title: 'Manage Tests',
                      description: 'Update test catalog and pricing',
                      icon: Icons.science,
                      onTap: () => context.go('/admin/tests'),
                    ),
                  ],
                  if (auth.isBloodBankAdmin)
                    _AdminActionCard(
                      title: 'Manage Blood Stock',
                      description: 'Update blood inventory and fees',
                      icon: Icons.bloodtype,
                      onTap: () => context.go('/admin/blood-stock'),
                    ),
                  if (auth.isAmbulanceAdmin)
                    _AdminActionCard(
                      title: 'Manage Fleet',
                      description: 'Update vehicles, status, and fares',
                      icon: Icons.emergency,
                      onTap: () => context.go('/admin/ambulances'),
                    ),
                  _AdminActionCard(
                    title: 'Booking Requests',
                    description: 'Review and manage incoming requests',
                    icon: Icons.list_alt,
                    onTap: () => context.go('/admin/requests'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionCard({required this.title, required this.description, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
