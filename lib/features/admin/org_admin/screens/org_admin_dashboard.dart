import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../features/ambulance/providers/ambulance_provider.dart';
import '../../../../features/beds/providers/bed_provider.dart';
import '../../../../features/blood_bank/providers/blood_provider.dart';
import '../../../../features/tests/providers/test_provider.dart';
import '../../../../models/booking_request_model.dart';
import '../../../../models/organization_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../providers/organization_provider.dart';

class OrgAdminDashboard extends StatefulWidget {
  const OrgAdminDashboard({super.key});

  @override
  State<OrgAdminDashboard> createState() => _OrgAdminDashboardState();
}

class _OrgAdminDashboardState extends State<OrgAdminDashboard> {
  OrganizationModel? _org;
  bool _isLoading = true;
  String? _loadedOrgId;
  String? _loadedRole;
  StreamSubscription<List<BookingRequestModel>>? _bookingSubscription;
  List<BookingRequestModel> _liveBookings = [];
  bool _bookingsLoading = false;
  String? _bookingsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final orgId = auth.user?.organizationId;
    final role = auth.user?.role;
    if (orgId == _loadedOrgId && role == _loadedRole) return;

    _loadedOrgId = orgId;
    _loadedRole = role;
    Future.microtask(() => _loadOrg(orgId));
  }

  Future<void> _loadOrg(String? orgId) async {
    if (mounted) {
      setState(() {
        _org = null;
        _isLoading = true;
      });
    }

    if (orgId != null) {
      final org = await context.read<OrganizationProvider>().getOrganization(
        orgId,
      );
      if (!mounted ||
          context.read<AuthProvider>().user?.organizationId != orgId) {
        return;
      }
      setState(() {
        _org = org;
        _isLoading = false;
      });
      if (org != null) {
        await _loadDashboardData(org);
      }
    } else {
      await _bookingSubscription?.cancel();
      _bookingSubscription = null;
      if (mounted) {
        setState(() {
          _org = null;
          _isLoading = false;
          _liveBookings = [];
          _bookingsLoading = false;
          _bookingsError = null;
        });
      }
    }
  }

  Future<void> _loadDashboardData(OrganizationModel org) async {
    final auth = context.read<AuthProvider>();
    final requestType = auth.isBedAdmin
        ? 'bed'
        : auth.isBloodBankAdmin
        ? 'blood'
        : auth.isAmbulanceAdmin
        ? 'ambulance'
        : null;
    await _bookingSubscription?.cancel();
    _bookingSubscription = null;
    if (!mounted) return;

    setState(() {
      _liveBookings = [];
      _bookingsError = null;
      _bookingsLoading = requestType != null;
    });

    if (requestType != null) {
      _bookingSubscription = context
          .read<BookingProvider>()
          .watchOrganizationBookings(org.id, type: requestType)
          .listen(
            (bookings) {
              if (!mounted) return;
              setState(() {
                _liveBookings = bookings;
                _bookingsLoading = false;
                _bookingsError = null;
              });
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _bookingsLoading = false;
                _bookingsError = error.toString();
              });
            },
          );
    }

    await Future.wait([
      if (auth.isBedAdmin) context.read<BedProvider>().fetchBedsForOrg(org.id),
      if (auth.isTestAdmin)
        context.read<TestProvider>().fetchTestsForOrg(org.id),
      if (auth.isBloodBankAdmin)
        context.read<BloodProvider>().fetchStockForOrg(org.id),
      if (auth.isAmbulanceAdmin)
        context.read<AmbulanceProvider>().fetchAmbulancesForOrg(org.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final beds = context.watch<BedProvider>().getBedsForHospital(
      _org?.id ?? '',
    );
    final tests = context.watch<TestProvider>().getTestsForOrg(_org?.id ?? '');
    final bloodStock = context.watch<BloodProvider>().getStockForOrg(
      _org?.id ?? '',
    );
    final ambulances = context.watch<AmbulanceProvider>().getAmbulancesForOrg(
      _org?.id ?? '',
    );

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_org == null) {
      return const Center(
        child: Text(
          'No organization assigned. Contact the platform administrator.',
        ),
      );
    }

    final handlesBookings =
        auth.isBedAdmin || auth.isBloodBankAdmin || auth.isAmbulanceAdmin;
    final bookings = handlesBookings ? _liveBookings : const [];
    final pending = bookings.where((b) => b.isPending).length;
    final confirmed = bookings.where((b) => b.isConfirmed).length;
    final terminal = bookings.where((b) => b.isTerminal).length;
    final now = DateTime.now();
    final today = bookings
        .where(
          (b) =>
              b.createdAt.year == now.year &&
              b.createdAt.month == now.month &&
              b.createdAt.day == now.day,
        )
        .length;
    final availableBeds = beds.fold(0, (sum, b) => sum + b.availableBeds);
    final totalBeds = beds.fold(0, (sum, b) => sum + b.totalBeds);
    final availableUnits = bloodStock.fold(
      0,
      (sum, s) => sum + s.availableUnits,
    );
    final totalUnits = bloodStock.fold(0, (sum, s) => sum + s.totalUnits);
    final availableAmbulances = ambulances.where((a) => a.isAvailable).length;

    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(_org!),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(
                  org: _org!,
                  roleLabel: auth.user?.roleLabel ?? 'Organization Admin',
                  isLoading: handlesBookings && _bookingsLoading,
                  onRefresh: () => _loadDashboardData(_org!),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (handlesBookings) ...[
                      _StatCard(
                        title: 'Pending',
                        value: '$pending',
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Confirmed',
                        value: '$confirmed',
                        icon: Icons.verified,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'Today',
                        value: '$today',
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Closed',
                        value: '$terminal',
                        icon: Icons.task_alt,
                        color: Colors.blueGrey,
                      ),
                    ],
                    if (auth.isBedAdmin)
                      _StatCard(
                        title: 'Available Beds',
                        value: '$availableBeds/$totalBeds',
                        icon: Icons.bed,
                        color: Colors.indigo,
                      ),
                    if (auth.isTestAdmin)
                      _StatCard(
                        title: 'Tests Listed',
                        value: '${tests.length}',
                        icon: Icons.science,
                        color: Colors.purple,
                      ),
                    if (auth.isBloodBankAdmin)
                      _StatCard(
                        title: 'Blood Units',
                        value: '$availableUnits/$totalUnits',
                        icon: Icons.bloodtype,
                        color: Colors.red,
                      ),
                    if (auth.isAmbulanceAdmin)
                      _StatCard(
                        title: 'Available Fleet',
                        value: '$availableAmbulances/${ambulances.length}',
                        icon: Icons.emergency,
                        color: Colors.deepOrange,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Quick Actions',
                  subtitle: handlesBookings
                      ? 'Update availability first, then handle incoming requests.'
                      : 'Keep the diagnostic test catalog, pricing, and turnaround times current.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    if (auth.isBedAdmin)
                      _AdminActionCard(
                        title: 'Manage Beds',
                        description: 'Update bed types, counts, and pricing',
                        icon: Icons.bed,
                        badge: '$availableBeds available',
                        onTap: () => context.go('/admin/beds'),
                      ),
                    if (auth.isTestAdmin)
                      _AdminActionCard(
                        title: 'Manage Tests',
                        description: 'Update test catalog and pricing',
                        icon: Icons.science,
                        badge: '${tests.length} tests',
                        onTap: () => context.go('/admin/tests'),
                      ),
                    if (auth.isBloodBankAdmin)
                      _AdminActionCard(
                        title: 'Manage Blood Stock',
                        description: 'Update blood inventory and fees',
                        icon: Icons.bloodtype,
                        badge: '$availableUnits units',
                        onTap: () => context.go('/admin/blood-stock'),
                      ),
                    if (auth.isAmbulanceAdmin)
                      _AdminActionCard(
                        title: 'Manage Fleet',
                        description: 'Update vehicles, status, and fares',
                        icon: Icons.emergency,
                        badge: '$availableAmbulances available',
                        onTap: () => context.go('/admin/ambulances'),
                      ),
                    if (handlesBookings)
                      _AdminActionCard(
                        title: 'Booking Requests',
                        description: 'Review and manage incoming requests',
                        icon: Icons.list_alt,
                        badge: '$pending pending',
                        onTap: () => context.go('/admin/requests'),
                      ),
                  ],
                ),
                if (handlesBookings && _bookingsError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(
                    message: _bookingsError!.contains('permission-denied')
                        ? 'Booking information is unavailable because the Firestore rules for this new role have not been deployed yet.'
                        : 'Unable to receive live booking updates: $_bookingsError',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }
}

class _DashboardHeader extends StatelessWidget {
  final OrganizationModel org;
  final String roleLabel;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _DashboardHeader({
    required this.org,
    required this.roleLabel,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primary,
              child: Icon(
                Icons.admin_panel_settings,
                color: colorScheme.onPrimary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    org.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _InfoChip(icon: Icons.location_on, label: org.address),
                      _InfoChip(icon: Icons.phone, label: org.phone),
                      if (org.email != null && org.email!.trim().isNotEmpty)
                        _InfoChip(icon: Icons.email, label: org.email!),
                      _InfoChip(
                        icon: org.verified
                            ? Icons.verified
                            : Icons.warning_amber,
                        label: org.verified ? 'Verified' : 'Not verified',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh dashboard',
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(color: Colors.grey.shade600)),
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
  final String badge;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.badge,
    required this.onTap,
  });

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
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
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
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}
