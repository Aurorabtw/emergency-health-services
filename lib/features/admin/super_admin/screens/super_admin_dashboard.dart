import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../providers/organization_provider.dart';
import '../../../../services/seed_data_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().fetchOrganizations();
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final hospitals = orgProvider.organizations
        .where((o) => o.type == 'hospital')
        .length;
    final bloodBanks = orgProvider.organizations
        .where((o) => o.type == 'blood_bank')
        .length;
    final ambulanceOps = orgProvider.organizations
        .where((o) => o.type == 'ambulance_operator')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform Administration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Hospitals',
                    count: hospitals,
                    icon: Icons.local_hospital,
                    color: Colors.blue,
                    onTap: () =>
                        context.go('/super-admin/organizations?type=hospital'),
                  ),
                  _StatCard(
                    title: 'Blood Banks',
                    count: bloodBanks,
                    icon: Icons.bloodtype,
                    color: Colors.red,
                    onTap: () => context.go(
                      '/super-admin/organizations?type=blood_bank',
                    ),
                  ),
                  _StatCard(
                    title: 'Ambulance Operators',
                    count: ambulanceOps,
                    icon: Icons.emergency,
                    color: Colors.orange,
                    onTap: () => context.go(
                      '/super-admin/organizations?type=ambulance_operator',
                    ),
                  ),
                  _StatCard(
                    title: 'Total Organizations',
                    count: orgProvider.organizations.length,
                    icon: Icons.business,
                    color: Colors.teal,
                    onTap: () => context.go('/super-admin/organizations'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Manage Organizations',
                      description: 'Add, verify, and manage all organizations',
                      icon: Icons.business,
                      onTap: () => context.go('/super-admin/organizations'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      title: 'Manage Users',
                      description: 'Assign admin roles to users',
                      icon: Icons.people,
                      onTap: () => context.go('/super-admin/users'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ActionCard(
                title: 'All Booking Requests',
                description:
                    'View and oversee all booking requests across organizations',
                icon: Icons.list_alt,
                onTap: () => context.go('/super-admin/requests'),
              ),
              if (orgProvider.organizations.isEmpty &&
                  !orgProvider.isLoading) ...[
                const SizedBox(height: 32),
                _SeedDataCard(
                  onSeeded: () {
                    context.read<OrganizationProvider>().fetchOrganizations();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(title, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeedDataCard extends StatefulWidget {
  final VoidCallback onSeeded;

  const _SeedDataCard({required this.onSeeded});

  @override
  State<_SeedDataCard> createState() => _SeedDataCardState();
}

class _SeedDataCardState extends State<_SeedDataCard> {
  bool _loading = false;
  String? _message;

  Future<void> _seed() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final service = SeedDataService();
      final alreadyHasData = await service.hasData();
      if (alreadyHasData) {
        setState(() {
          _loading = false;
          _message = 'Demo data already exists.';
        });
        return;
      }
      await service.seedAll();
      setState(() {
        _loading = false;
        _message = 'Demo data loaded successfully!';
      });
      widget.onSeeded();
    } catch (e) {
      setState(() {
        _loading = false;
        _message = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dataset, size: 32, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No organizations yet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Load demo data with sample hospitals, blood banks, and ambulance operators to get started.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.startsWith('Error')
                        ? Colors.red
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _seed,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_loading ? 'Loading...' : 'Load Demo Data'),
            ),
          ],
        ),
      ),
    );
  }
}
