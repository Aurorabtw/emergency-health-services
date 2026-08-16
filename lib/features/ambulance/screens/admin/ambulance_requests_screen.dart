import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';
import '../../../../shared/widgets/prescription_image.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/ambulance_provider.dart';

class AmbulanceRequestsScreen extends StatefulWidget {
  const AmbulanceRequestsScreen({super.key});

  @override
  State<AmbulanceRequestsScreen> createState() =>
      _AmbulanceRequestsScreenState();
}

class _AmbulanceRequestsScreenState extends State<AmbulanceRequestsScreen> {
  String? _orgId;
  String? _scopeKey;
  List<BookingRequestModel> _bookings = [];
  bool _isLoading = false;
  int _scopeGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final scopeKey = '${user?.uid}|${user?.role}|${user?.organizationId}';
    if (scopeKey == _scopeKey) return;
    _scopeKey = scopeKey;
    _orgId = auth.isAmbulanceAdmin ? user?.organizationId : null;
    _bookings = [];
    _isLoading = _orgId != null;
    final generation = ++_scopeGeneration;
    if (_orgId != null) {
      Future.microtask(() => _loadRequests(generation: generation));
    }
  }

  Future<void> _loadRequests({int? generation}) async {
    final organizationId = _orgId;
    final capturedGeneration = generation ?? _scopeGeneration;
    if (organizationId == null) return;
    if (!_isCurrentScope(organizationId, capturedGeneration)) return;
    if (generation == null) setState(() => _isLoading = true);
    final bookingProvider = context.read<BookingProvider>();
    await Future.wait([
      bookingProvider.fetchOrganizationBookings(
        organizationId,
        type: 'ambulance',
      ),
      context.read<AmbulanceProvider>().fetchAmbulancesForOrg(organizationId),
    ]);
    if (!_isCurrentScope(organizationId, capturedGeneration)) return;
    setState(() {
      _bookings = bookingProvider.bookings
          .where(
            (booking) =>
                booking.organizationId == organizationId &&
                booking.type == 'ambulance',
          )
          .toList();
      _isLoading = false;
    });
  }

  bool _isCurrentScope(String organizationId, int generation) {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    return generation == _scopeGeneration &&
        _orgId == organizationId &&
        auth.isAmbulanceAdmin &&
        auth.user?.organizationId == organizationId;
  }

  Future<void> _approve(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || booking.organizationId != organizationId) {
      return;
    }
    try {
      final ambulances = context.read<AmbulanceProvider>().getAmbulancesForOrg(
        organizationId,
      );
      final match = ambulances
          .where((a) => a.type == booking.ambulanceType && a.isAvailable)
          .firstOrNull;
      if (match == null) {
        throw const BookingOperationException(
          'No available ambulance of this type. Update the fleet or refresh the request.',
        );
      }

      await context.read<BookingProvider>().confirmAmbulanceBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        ambulanceId: match.id,
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _loadRequests(generation: generation);
      if (!_isCurrentScope(organizationId, generation)) return;
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _complete(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || booking.organizationId != organizationId) {
      return;
    }
    try {
      final ambulances = context.read<AmbulanceProvider>().getAmbulancesForOrg(
        organizationId,
      );
      final match = booking.ambulanceId != null
          ? ambulances.where((a) => a.id == booking.ambulanceId).firstOrNull
          : ambulances
                .where((a) => a.type == booking.ambulanceType && !a.isAvailable)
                .firstOrNull;
      if (match == null) {
        throw const BookingOperationException(
          'The ambulance assigned to this trip could not be found.',
        );
      }

      await context.read<BookingProvider>().completeAmbulanceBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        ambulanceId: match.id,
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _loadRequests(generation: generation);
      if (!_isCurrentScope(organizationId, generation)) return;
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _reject(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || booking.organizationId != organizationId) {
      return;
    }
    await context.read<BookingProvider>().rejectBooking(booking.id);
    if (!_isCurrentScope(organizationId, generation)) return;
    await _loadRequests(generation: generation);
    if (!_isCurrentScope(organizationId, generation)) return;
  }

  Future<void> _loadMore() async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null) return;
    final bookingProvider = context.read<BookingProvider>();
    await bookingProvider.loadMoreBookings();
    if (!_isCurrentScope(organizationId, generation)) return;
    setState(() {
      _bookings = bookingProvider.bookings
          .where(
            (booking) =>
                booking.organizationId == organizationId &&
                booking.type == 'ambulance',
          )
          .toList();
    });
  }

  Future<void> _cleanTerminalBookings() async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null) return;
    await _loadRequests(generation: generation);
    if (!_isCurrentScope(organizationId, generation)) return;
    await context.read<BookingProvider>().clearTerminalBookings();
    if (!_isCurrentScope(organizationId, generation)) return;
    setState(() => _bookings.removeWhere((booking) => booking.isTerminal));
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) {
      return const Center(child: Text('No organization assigned'));
    }

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
                    'Ambulance Requests',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_bookings.any((b) => b.isTerminal))
                    TextButton.icon(
                      onPressed: () async {
                        await _cleanTerminalBookings();
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
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_bookings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('No ambulance requests'),
                  ),
                )
              else
                ..._bookings.map(
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
                                        'Type: ${booking.ambulanceType ?? "-"}',
                                      ),
                                      if (booking.pickupAddress != null)
                                        Text(
                                          'Pickup: ${booking.pickupAddress}',
                                        ),
                                      if (booking.destinationAddress != null)
                                        Text(
                                          'Destination: ${booking.destinationAddress}',
                                        ),
                                      if (booking.patientConditionNotes != null)
                                        Text(
                                          'Notes: ${booking.patientConditionNotes}',
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
                            PrescriptionDialogButton(
                              documentId: booking.prescriptionDocumentId,
                              assetBookingId: booking.prescriptionAssetId,
                              legacyUrl: booking.prescriptionImageUrl,
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
                                    child: const Text('Confirm Trip'),
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
                                    child: const Text('Mark as Completed'),
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
              if (context.watch<BookingProvider>().hasMoreBookings) ...[
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ||
                            context.watch<BookingProvider>().isLoadingMore
                        ? null
                        : _loadMore,
                    icon: context.watch<BookingProvider>().isLoadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      context.watch<BookingProvider>().isLoadingMore
                          ? 'Loading…'
                          : 'Load older requests',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
