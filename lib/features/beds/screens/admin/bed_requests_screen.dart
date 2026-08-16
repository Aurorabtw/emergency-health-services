import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';
import '../../../../shared/widgets/prescription_image.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/bed_provider.dart';

class BedRequestsScreen extends StatefulWidget {
  const BedRequestsScreen({super.key});

  @override
  State<BedRequestsScreen> createState() => _BedRequestsScreenState();
}

class _BedRequestsScreenState extends State<BedRequestsScreen> {
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
    _orgId = auth.isBedAdmin ? user?.organizationId : null;
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
      bookingProvider.fetchOrganizationBookings(organizationId, type: 'bed'),
      context.read<BedProvider>().fetchBedsForOrg(organizationId),
    ]);
    if (!_isCurrentScope(organizationId, capturedGeneration)) return;
    setState(() {
      _bookings = bookingProvider.bookings
          .where(
            (booking) =>
                booking.organizationId == organizationId &&
                booking.type == 'bed',
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
        auth.isBedAdmin &&
        auth.user?.organizationId == organizationId;
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

  Future<void> _reject(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || !_canActOn(booking, organizationId)) return;
    await context.read<BookingProvider>().rejectBooking(booking.id);
    if (!_isCurrentScope(organizationId, generation)) return;
    await _loadRequests(generation: generation);
    if (!_isCurrentScope(organizationId, generation)) return;
  }

  Future<void> _reloadAfterAction(String organizationId, int generation) async {
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
                booking.type == 'bed',
          )
          .toList();
    });
  }

  bool _canActOn(BookingRequestModel booking, String organizationId) =>
      booking.organizationId == organizationId;

  Future<void> _approve(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || !_canActOn(booking, organizationId)) return;
    try {
      final beds = context.read<BedProvider>().getBedsForHospital(
        organizationId,
      );
      final bed = beds.firstWhere(
        (b) => booking.bedId != null
            ? b.id == booking.bedId
            : b.type == booking.bedType,
      );

      await context.read<BookingProvider>().confirmBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        resourceId: bed.id,
        bookingType: 'bed',
        holdMinutes: bed.holdDurationMinutes,
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _reloadAfterAction(organizationId, generation);
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _admit(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || !_canActOn(booking, organizationId)) return;
    try {
      final beds = context.read<BedProvider>().getBedsForHospital(
        organizationId,
      );
      final bed = beds.firstWhere(
        (b) => booking.bedId != null
            ? b.id == booking.bedId
            : b.type == booking.bedType,
      );

      await context.read<BookingProvider>().admitBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        resourceId: bed.id,
        bookingType: 'bed',
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _reloadAfterAction(organizationId, generation);
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _discharge(BookingRequestModel booking) async {
    final bedId = booking.bedId;
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (bedId == null ||
        organizationId == null ||
        !_canActOn(booking, organizationId)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discharge Patient'),
        content: Text(
          'Discharge ${booking.patientName} and release one ${booking.bedType ?? 'bed'} bed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discharge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_isCurrentScope(organizationId, generation)) {
      return;
    }
    try {
      await context.read<BookingProvider>().dischargeBedBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        bedId: bedId,
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _reloadAfterAction(organizationId, generation);
    } catch (error) {
      if (!_isCurrentScope(organizationId, generation)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
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
                    'Bed Booking Requests',
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
                    child: Text('No booking requests'),
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
                                        'Bed Type: ${booking.bedType ?? "-"}',
                                      ),
                                      if (booking.estimatedPrice != null)
                                        PriceWidget(
                                          price: booking.estimatedPrice,
                                          label: 'day',
                                        ),
                                    ],
                                  ),
                                ),
                                BookingStatusChip(
                                  status: booking.status,
                                  bookingType: booking.type,
                                ),
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
                                    onPressed: () => _admit(booking),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('Mark as Admitted'),
                                  ),
                                ],
                              ),
                            ],
                            if (booking.isAdmitted) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: () => _discharge(booking),
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Discharge Patient'),
                                ),
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
                    onPressed: _isLoading
                        ? null
                        : context.watch<BookingProvider>().isLoadingMore
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
