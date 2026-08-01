import 'package:flutter/material.dart';

enum SortOption { distance, priceLowHigh, priceHighLow }

class SortFilterBar extends StatelessWidget {
  final SortOption currentSort;
  final ValueChanged<SortOption> onSortChanged;
  final List<String>? filterOptions;
  final String? selectedFilter;
  final ValueChanged<String?>? onFilterChanged;
  final String? filterLabel;

  const SortFilterBar({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
    this.filterOptions,
    this.selectedFilter,
    this.onFilterChanged,
    this.filterLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (filterOptions != null && onFilterChanged != null) ...[
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedFilter,
                decoration: InputDecoration(
                  labelText: filterLabel ?? 'Filter',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...filterOptions!.map(
                    (f) => DropdownMenuItem(value: f, child: Text(f)),
                  ),
                ],
                onChanged: onFilterChanged,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: DropdownButtonFormField<SortOption>(
              value: currentSort,
              decoration: const InputDecoration(
                labelText: 'Sort by',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: SortOption.distance, child: Text('Distance')),
                DropdownMenuItem(value: SortOption.priceLowHigh, child: Text('Price: Low to High')),
                DropdownMenuItem(value: SortOption.priceHighLow, child: Text('Price: High to Low')),
              ],
              onChanged: (v) {
                if (v != null) onSortChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
