import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/bed_provider.dart';

class BedRequestsScreen extends StatefulWidget {
  const BedRequestsScreen({super.key});

  @override
  State<BedRequestsScreen> createState() => _BedRequestsScreenState();
}

class _BedRequestsScreenState extends State<BedRequestsScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgId = context.read<AuthProvider>().user?.organizationId;
    _loadRequests();
  }

  void _loadRequests() {
    if (_orgId != null) {
      context.read<BookingProvider>().fetchOrganizationBookings(_orgId!, type: 'bed');
      context.read<BedProvider>().fetchBedsForOrg(_orgId!);
    }
  }

  Future<void> _approve(BookingRequestModel booking) async {
    try {
      final beds = context.read<BedProvider>().getBedsForHospital(_orgId!);
      final bed = beds.firstWhere((b) => b.type == booking.bedType);

      await context.read<BookingProvider>().confirmBooking(
            booking.id,
            'organizations/$_orgId/beds/${bed.id}',
            'held_beds',
            bed.holdDurationMinutes,
          );
      _loadRequests();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _admit(BookingRequestModel booking) async {
    try {
      final beds = context.read<BedProvider>().getBedsForHospital(_orgId!);
      final bed = beds.firstWhere((b) => b.type == booking.bedType);

      await context.read<BookingProvider>().admitBooking(
            booking.id,
            'organizations/$_orgId/beds/${bed.id}',
            'held_beds',
            'admitted_beds',
          );
      _loadRequests();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(BookingRequestModel booking) async {
    await context.read<BookingProvider>().rejectBooking(booking.id);
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Bed Booking Requests', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (bookingProvider.bookings.any((b) => b.isTerminal))
                    TextButton.icon(
                      onPressed: () async {
                        await context.read<BookingProvider>().clearTerminalBookings();
                      },
                      icon: const Icon(Icons.cleaning_services, size: 18),
                      label: const Text('Clean'),
                    ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
                ],
              ),
              const SizedBox(height: 16),
              if (bookingProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (bookingProvider.bookings.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No booking requests')))
              else
                ...bookingProvider.bookings.map(
                  (booking) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                                    Text(booking.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Phone: ${booking.contactNumber}'),
                                    Text('Bed Type: ${booking.bedType ?? "-"}'),
                                    if (booking.estimatedPrice != null)
                                      PriceWidget(price: booking.estimatedPrice, label: 'day'),
                                  ],
                                ),
                              ),
                              BookingStatusChip(status: booking.status),
                            ],
                          ),
                          if (booking.prescriptionImageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AppBar(
                                            title: const Text('Prescription'),
                                            automaticallyImplyLeading: false,
                                            actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
                                          ),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxHeight: 500, maxWidth: 600),
                                            child: Image.network(
                                              booking.prescriptionImageUrl!,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => const Padding(
                                                padding: EdgeInsets.all(48),
                                                child: Text('Image unavailable'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.image),
                                label: const Text('View Prescription'),
                              ),
                            ),
                          if (booking.isPending) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _reject(booking),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(onPressed: () => _approve(booking), child: const Text('Approve & Hold')),
                              ],
                            ),
                          ],
                          if (booking.isConfirmed) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton(
                                  onPressed: () => _admit(booking),
                                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Mark as Admitted'),
                                ),
                              ],
                            ),
                          ],
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
}
