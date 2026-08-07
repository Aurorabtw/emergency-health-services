import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/location_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/price_widget.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/sort_filter_bar.dart';
import '../providers/test_provider.dart';

class TestSearchScreen extends StatefulWidget {
  const TestSearchScreen({super.key});

  @override
  State<TestSearchScreen> createState() => _TestSearchScreenState();
}

class _TestSearchScreenState extends State<TestSearchScreen> {
  final _searchController = TextEditingController();
  SortOption _sortOption = SortOption.distance;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final orgProvider = context.read<OrganizationProvider>();
    final testProvider = context.read<TestProvider>();
    final locationProvider = context.read<LocationProvider>();

    await locationProvider.getCurrentLocation();
    await orgProvider.fetchVerifiedOrganizations(type: 'hospital');
    await testProvider.fetchTestsForOrganizations(orgProvider.organizations);

    if (mounted) setState(() => _dataLoaded = true);
  }

  void _onSearch(String query) {
    final orgProvider = context.read<OrganizationProvider>();
    context.read<TestProvider>().searchTests(query, orgProvider.organizations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final testProvider = context.watch<TestProvider>();
    final locationProvider = context.watch<LocationProvider>();

    var results = List.of(testProvider.searchResults);

    if (_sortOption == SortOption.distance && locationProvider.hasLocation) {
      results.sort((a, b) {
        final dA = locationProvider.distanceTo(a.organization.latitude, a.organization.longitude) ?? double.infinity;
        final dB = locationProvider.distanceTo(b.organization.latitude, b.organization.longitude) ?? double.infinity;
        return dA.compareTo(dB);
      });
    } else if (_sortOption == SortOption.priceLowHigh) {
      results.sort((a, b) => a.test.price.compareTo(b.test.price));
    } else if (_sortOption == SortOption.priceHighLow) {
      results.sort((a, b) => b.test.price.compareTo(a.test.price));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diagnostic Test Locator', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Search for tests and compare prices across hospitals', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tests (e.g., MRI Brain, CBC, HbA1c...)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onSearch,
              ),
              const SizedBox(height: 8),
              SortFilterBar(
                currentSort: _sortOption,
                onSortChanged: (v) => setState(() => _sortOption = v),
              ),
              const SizedBox(height: 16),
              if (!_dataLoaded)
                const ListingSkeletonList()
              else if (_searchController.text.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(Icons.science, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Search for a test to see results', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                )
              else if (results.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text('No tests found matching "${_searchController.text}"', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                )
              else
                ...results.map((result) {
                  final distance = locationProvider.distanceTo(result.organization.latitude, result.organization.longitude);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(result.test.testName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(result.organization.name, style: TextStyle(color: Colors.grey.shade700)),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(result.organization.address, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                                    if (distance != null)
                                      Text(locationProvider.formatDistance(distance), style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    PriceWidget(price: result.test.price, prominent: true),
                                    if (result.test.turnaroundTime.isNotEmpty)
                                      Chip(
                                        avatar: const Icon(Icons.timer, size: 16),
                                        label: Text(result.test.turnaroundTime, style: const TextStyle(fontSize: 12)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    if (result.test.homeCollection)
                                      Chip(
                                        avatar: const Icon(Icons.home, size: 16, color: Colors.green),
                                        label: Text(
                                          result.test.homeCollectionSurcharge != null
                                              ? 'Home +৳${result.test.homeCollectionSurcharge!.toStringAsFixed(0)}'
                                              : 'Home Collection',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            tooltip: 'Call ${result.organization.phone}',
                            onPressed: () => launchUrl(Uri.parse('tel:${result.organization.phone}')),
                          ),
                        ],
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
