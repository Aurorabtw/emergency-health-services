import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/blood_provider.dart';

class BloodRequestsScreen extends StatefulWidget {
  const BloodRequestsScreen({super.key});

  @override
  State<BloodRequestsScreen> createState() => _BloodRequestsScreenState();
}

class _BloodRequestsScreenState extends State<BloodRequestsScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _orgId = context.read<AuthProvider>().user?.organizationId;
    _loadRequests();
  }

  void _loadRequests() {
    if (_orgId != null) {
      context.read<BookingProvider>().fetchOrganizationBookings(
        _orgId!,
        type: 'blood',
      );
      context.read<BloodProvider>().fetchStockForOrg(_orgId!);
    }
  }

  Future<void> _approve(BookingRequestModel booking) async {
    try {
      final stock = context.read<BloodProvider>().getStockForOrg(_orgId!);
      final match = stock.firstWhere((s) => s.bloodType == booking.bloodType);

      await context.read<BookingProvider>().confirmBooking(
        booking.id,
        'organizations/$_orgId/blood_stock/${match.id}',
        'held_units',
        60,
      );
      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _complete(BookingRequestModel booking) async {
    try {
      final stock = context.read<BloodProvider>().getStockForOrg(_orgId!);
      final match = stock.firstWhere((s) => s.bloodType == booking.bloodType);

      await context.read<BookingProvider>().admitBooking(
        booking.id,
        'organizations/$_orgId/blood_stock/${match.id}',
        'held_units',
        'issued_units',
      );
      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
                  Text(
                    'Blood Requests',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (bookingProvider.bookings.any((b) => b.isTerminal))
                    TextButton.icon(
                      onPressed: () async {
                        await context
                            .read<BookingProvider>()
                            .clearTerminalBookings();
                      },
                      icon: const Icon(Icons.cleaning_services, size: 18),
                      label: const Text('Clean'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadRequests,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (bookingProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (bookingProvider.bookings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('No blood requests'),
                  ),
                )
              else
                ...bookingProvider.bookings.map(
                  (booking) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/booking/${booking.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.patientName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text('Phone: ${booking.contactNumber}'),
                                      Text(
                                        'Blood Type: ${booking.bloodType ?? "-"}  |  Units: ${booking.unitsNeeded ?? 0}',
                                      ),
                                      Text(
                                        'Hospital: ${booking.hospitalName ?? "-"}',
                                      ),
                                      Text(
                                        'Doctor: ${booking.prescribingDoctor ?? "-"}',
                                      ),
                                      if (booking.estimatedPrice != null)
                                        PriceWidget(
                                          price: booking.estimatedPrice,
                                        ),
                                    ],
                                  ),
                                ),
                                BookingStatusChip(status: booking.status),
                              ],
                            ),
                            if (booking.isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _reject(booking),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => _approve(booking),
                                    child: const Text('Approve & Hold'),
                                  ),
                                ],
                              ),
                            ],
                            if (booking.isConfirmed) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    onPressed: () => _complete(booking),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('Mark as Collected'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
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
