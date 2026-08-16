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
import '../providers/ambulance_provider.dart';

class AmbulanceListingsScreen extends StatefulWidget {
  const AmbulanceListingsScreen({super.key});

  @override
  State<AmbulanceListingsScreen> createState() => _AmbulanceListingsScreenState();
}

class _AmbulanceListingsScreenState extends State<AmbulanceListingsScreen> {
  SortOption _sortOption = SortOption.distance;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final orgProvider = context.read<OrganizationProvider>();
    final ambProvider = context.read<AmbulanceProvider>();
    final locationProvider = context.read<LocationProvider>();

    // Load listings first so the page renders even if location is slow or denied.
    await orgProvider.fetchVerifiedOrganizations(type: 'ambulance_operator');
    await ambProvider.fetchAmbulancesForOperators(orgProvider.organizations);

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
    final ambProvider = context.watch<AmbulanceProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isLoading = orgProvider.isLoading || ambProvider.isLoading;

    var operators = orgProvider.getByType('ambulance_operator');

    if (_sortOption == SortOption.distance && locationProvider.hasLocation) {
      operators.sort((a, b) {
        final dA = locationProvider.distanceTo(a.latitude, a.longitude, orgId: a.id) ?? double.infinity;
        final dB = locationProvider.distanceTo(b.latitude, b.longitude, orgId: b.id) ?? double.infinity;
        return dA.compareTo(dB);
      });
    } else if (_sortOption == SortOption.priceLowHigh) {
      operators.sort((a, b) {
        final fA = _getMinFare(ambProvider, a.id);
        final fB = _getMinFare(ambProvider, b.id);
        return fA.compareTo(fB);
      });
    } else if (_sortOption == SortOption.priceHighLow) {
      operators.sort((a, b) {
        final fA = _getMinFare(ambProvider, a.id);
        final fB = _getMinFare(ambProvider, b.id);
        return fB.compareTo(fA);
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
              Text('Emergency Ambulance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Book the nearest available ambulance', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              SortFilterBar(
                currentSort: _sortOption,
                onSortChanged: (v) => setState(() => _sortOption = v),
                filterOptions: const ['Basic', 'AC', 'ICU'],
                selectedFilter: _typeFilter,
                onFilterChanged: (v) => setState(() => _typeFilter = v),
                filterLabel: 'Vehicle Type',
              ),
              const SizedBox(height: 16),
              if (!isLoading && operators.isNotEmpty)
                SharedMapView(
                  markers: operators.map((op) {
                    final ambulances = ambProvider.getAmbulancesForOrg(op.id);
                    final filtered = _typeFilter != null ? ambulances.where((a) => a.type == _typeFilter).toList() : ambulances;
                    final availableCount = filtered.where((a) => a.isAvailable).length;
                    return MapMarker(
                      id: op.id,
                      latitude: op.latitude,
                      longitude: op.longitude,
                      title: op.name,
                      snippet: op.address,
                      available: availableCount,
                      onTap: () => context.push('/ambulance/book/${op.id}'),
                    );
                  }).toList(),
                  centerLat: locationProvider.latitude,
                  centerLng: locationProvider.longitude,
                ),
              const SizedBox(height: 16),
              if (isLoading)
                const ListingSkeletonList()
              else if (operators.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(Icons.emergency, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No ambulance services found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                )
              else
                ...operators.map((op) {
                  final ambulances = ambProvider.getAmbulancesForOrg(op.id);
                  final filtered = _typeFilter != null ? ambulances.where((a) => a.type == _typeFilter).toList() : ambulances;
                  final availableCount = filtered.where((a) => a.isAvailable).length;
                  final distance = locationProvider.distanceTo(op.latitude, op.longitude, orgId: op.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => context.push('/ambulance/book/${op.id}'),
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
                                      Text(op.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(op.address, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
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
                                AvailabilityBadge(available: availableCount, label: 'available'),
                              ],
                            ),
                            if (filtered.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filtered.map((a) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: a.isAvailable ? Colors.green.shade50 : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: a.isAvailable ? Colors.green.shade200 : Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${a.type}  ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                        PriceWidget(price: a.baseFare, label: 'base'),
                                        if (a.perKmRate != null) Text('  + ৳${a.perKmRate!.toStringAsFixed(0)}/km', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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

  double _getMinFare(AmbulanceProvider provider, String orgId) {
    final ambulances = provider.getAmbulancesForOrg(orgId);
    if (ambulances.isEmpty) return double.infinity;
    return ambulances.map((a) => a.baseFare).reduce((a, b) => a < b ? a : b);
  }
}
