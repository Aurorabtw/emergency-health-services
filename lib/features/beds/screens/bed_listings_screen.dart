import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/organization_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_animations.dart';
import '../../../shared/widgets/availability_badge.dart';
import '../../../shared/widgets/map_view.dart';
import '../../../shared/widgets/price_widget.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/sort_filter_bar.dart';
import '../providers/bed_provider.dart';

class BedListingsScreen extends StatefulWidget {
  const BedListingsScreen({super.key});

  @override
  State<BedListingsScreen> createState() => _BedListingsScreenState();
}

class _BedListingsScreenState extends State<BedListingsScreen> {
  SortOption _sortOption = SortOption.distance;
  String? _bedTypeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final orgProvider = context.read<OrganizationProvider>();
    final bedProvider = context.read<BedProvider>();
    final locationProvider = context.read<LocationProvider>();

    await locationProvider.getCurrentLocation();
    await orgProvider.fetchVerifiedOrganizations(type: 'hospital');
    await bedProvider.fetchBedsForHospitals(orgProvider.organizations);

    // Fetch road distances for all hospitals
    if (locationProvider.hasLocation) {
      final destinations = orgProvider.organizations
          .map((o) => (lat: o.latitude, lng: o.longitude, id: o.id))
          .toList();
      await locationProvider.fetchRoadDistances(destinations);
    }
  }

  List<OrganizationModel> _sortedHospitals() {
    final orgProvider = context.read<OrganizationProvider>();
    final bedProvider = context.read<BedProvider>();
    final locationProvider = context.read<LocationProvider>();

    var hospitals = orgProvider.getByType('hospital');

    switch (_sortOption) {
      case SortOption.distance:
        if (locationProvider.hasLocation) {
          hospitals.sort((a, b) {
            final distA = locationProvider.distanceTo(a.latitude, a.longitude, orgId: a.id) ?? double.infinity;
            final distB = locationProvider.distanceTo(b.latitude, b.longitude, orgId: b.id) ?? double.infinity;
            return distA.compareTo(distB);
          });
        }
        break;
      case SortOption.priceLowHigh:
        hospitals.sort((a, b) {
          final priceA = _getMinPrice(bedProvider, a.id);
          final priceB = _getMinPrice(bedProvider, b.id);
          return priceA.compareTo(priceB);
        });
        break;
      case SortOption.priceHighLow:
        hospitals.sort((a, b) {
          final priceA = _getMinPrice(bedProvider, a.id);
          final priceB = _getMinPrice(bedProvider, b.id);
          return priceB.compareTo(priceA);
        });
        break;
    }

    return hospitals;
  }

  double _getMinPrice(BedProvider provider, String orgId) {
    final beds = provider.getBedsForHospital(orgId);
    if (beds.isEmpty) return double.infinity;
    if (_bedTypeFilter != null) {
      final filtered = beds.where((b) => b.type == _bedTypeFilter);
      if (filtered.isEmpty) return double.infinity;
      return filtered.first.pricePerDay;
    }
    return beds.map((b) => b.pricePerDay).reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final bedProvider = context.watch<BedProvider>();
    final locationProvider = context.watch<LocationProvider>();

    final isLoading = orgProvider.isLoading || bedProvider.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emergency Beds', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Find available hospital beds nearby', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              SortFilterBar(
                currentSort: _sortOption,
                onSortChanged: (v) => setState(() => _sortOption = v),
                filterOptions: const ['General', 'ICU', 'NICU'],
                selectedFilter: _bedTypeFilter,
                onFilterChanged: (v) => setState(() => _bedTypeFilter = v),
                filterLabel: 'Bed Type',
              ),
              const SizedBox(height: 16),
              if (!isLoading && orgProvider.organizations.isNotEmpty)
                SharedMapView(
                  markers: _sortedHospitals().map((h) => MapMarker(
                    id: h.id,
                    latitude: h.latitude,
                    longitude: h.longitude,
                    title: h.name,
                    snippet: h.address,
                    available: bedProvider.getTotalAvailable(h.id, bedType: _bedTypeFilter),
                    onTap: () => context.go('/beds/book/${h.id}'),
                  )).toList(),
                  centerLat: locationProvider.latitude,
                  centerLng: locationProvider.longitude,
                ),
              const SizedBox(height: 16),
              if (isLoading)
                const ListingSkeletonList()
              else if (orgProvider.organizations.isEmpty)
                _emptyState()
              else
                ..._sortedHospitals().asMap().entries.map((entry) {
                  final index = entry.key;
                  final hospital = entry.value;
                  final beds = bedProvider.getBedsForHospital(hospital.id);
                  final filteredBeds = _bedTypeFilter != null
                      ? beds.where((b) => b.type == _bedTypeFilter).toList()
                      : beds;
                  final totalAvailable = filteredBeds.fold(0, (sum, b) => sum + b.availableBeds);
                  final distance = locationProvider.distanceTo(hospital.latitude, hospital.longitude, orgId: hospital.id);

                  final card = Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => context.go('/beds/book/${hospital.id}'),
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
                                      Text(hospital.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(hospital.address, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                                          if (distance != null) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.directions_car, size: 13, color: Colors.grey.shade500),
                                            const SizedBox(width: 2),
                                            Text(locationProvider.formatDistance(distance),
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                AvailabilityBadge(available: totalAvailable),
                              ],
                            ),
                            if (filteredBeds.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: filteredBeds.map((bed) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${bed.type}: ', style: const TextStyle(fontSize: 13)),
                                        PriceWidget(price: bed.pricePerDay, label: 'day'),
                                        Text(' (${bed.availableBeds} avail)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeSlideIn(
                      // Stagger the first few cards; later ones appear together
                      delay: Duration(milliseconds: 60 * (index < 6 ? index : 6)),
                      duration: const Duration(milliseconds: 400),
                      child: HoverLift(lift: 2, child: card),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.bed, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No hospitals found nearby', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
