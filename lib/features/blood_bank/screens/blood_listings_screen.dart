import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/location_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/availability_badge.dart';
import '../../../shared/widgets/map_view.dart';
import '../../../shared/widgets/price_widget.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/sort_filter_bar.dart';
import '../providers/blood_provider.dart';

class BloodListingsScreen extends StatefulWidget {
  const BloodListingsScreen({super.key});

  @override
  State<BloodListingsScreen> createState() => _BloodListingsScreenState();
}

class _BloodListingsScreenState extends State<BloodListingsScreen> {
  SortOption _sortOption = SortOption.distance;
  String? _selectedBloodType;
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final orgProvider = context.read<OrganizationProvider>();
    final bloodProvider = context.read<BloodProvider>();
    final locationProvider = context.read<LocationProvider>();

    // Load listings first so the page renders even if location is slow or denied.
    await orgProvider.fetchVerifiedOrganizations(type: 'blood_bank');
    await bloodProvider.fetchStockForOrganizations(orgProvider.organizations);

    // Location + road distances are a non-blocking enhancement for distance sorting.
    await locationProvider.getCurrentLocation();
    if (locationProvider.hasLocation) {
      final destinations = orgProvider.organizations
          .map((o) => (lat: o.latitude, lng: o.longitude, id: o.id))
          .toList();
      await locationProvider.fetchRoadDistances(destinations);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final bloodProvider = context.watch<BloodProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isLoading = orgProvider.isLoading || bloodProvider.isLoading;

    var orgs = orgProvider.getByType('blood_bank');

    if (_sortOption == SortOption.distance && locationProvider.hasLocation) {
      orgs.sort((a, b) {
        final dA = locationProvider.distanceTo(a.latitude, a.longitude, orgId: a.id) ?? double.infinity;
        final dB = locationProvider.distanceTo(b.latitude, b.longitude, orgId: b.id) ?? double.infinity;
        return dA.compareTo(dB);
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emergency Blood Bank', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Find matching blood units nearby', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              SortFilterBar(
                currentSort: _sortOption,
                onSortChanged: (v) => setState(() => _sortOption = v),
                filterOptions: _bloodTypes,
                selectedFilter: _selectedBloodType,
                onFilterChanged: (v) => setState(() => _selectedBloodType = v),
                filterLabel: 'Blood Type',
              ),
              const SizedBox(height: 16),
              if (!isLoading && orgs.isNotEmpty)
                SharedMapView(
                  markers: orgs.map((o) {
                    final stock = bloodProvider.getStockForOrg(o.id);
                    final filtered = _selectedBloodType != null
                        ? stock.where((s) => s.bloodType == _selectedBloodType).toList()
                        : stock;
                    final totalAvailable = filtered.fold(0, (sum, s) => sum + s.availableUnits);
                    return MapMarker(
                      id: o.id,
                      latitude: o.latitude,
                      longitude: o.longitude,
                      title: o.name,
                      snippet: o.address,
                      available: totalAvailable,
                      onTap: () => context.go('/blood/request/${o.id}'),
                    );
                  }).toList(),
                  centerLat: locationProvider.latitude,
                  centerLng: locationProvider.longitude,
                ),
              const SizedBox(height: 16),
              if (isLoading)
                const ListingSkeletonList()
              else if (orgs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(Icons.bloodtype, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No blood banks found nearby', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                )
              else
                ...orgs.map((org) {
                  final stock = bloodProvider.getStockForOrg(org.id);
                  final filtered = _selectedBloodType != null
                      ? stock.where((s) => s.bloodType == _selectedBloodType).toList()
                      : stock;
                  final totalAvailable = filtered.fold(0, (sum, s) => sum + s.availableUnits);
                  final distance = locationProvider.distanceTo(org.latitude, org.longitude, orgId: org.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => context.go('/blood/request/${org.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(org.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(org.address, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                                          if (distance != null) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.directions_car, size: 13, color: Colors.grey.shade500),
                                            const SizedBox(width: 2),
                                            Text(locationProvider.formatDistance(distance), style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                AvailabilityBadge(available: totalAvailable, label: 'units'),
                              ],
                            ),
                            if (filtered.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filtered.map((s) {
                                  return Chip(
                                    avatar: Text(s.bloodType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${s.availableUnits} units  '),
                                        PriceWidget(price: s.processingFeePerUnit, label: 'unit'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
