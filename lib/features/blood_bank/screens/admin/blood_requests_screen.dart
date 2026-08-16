import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';
import '../../../../shared/widgets/prescription_image.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/blood_provider.dart';

class BloodRequestsScreen extends StatefulWidget {
  const BloodRequestsScreen({super.key});

  @override
  State<BloodRequestsScreen> createState() => _BloodRequestsScreenState();
}

class _BloodRequestsScreenState extends State<BloodRequestsScreen> {
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
    _orgId = auth.isBloodBankAdmin ? user?.organizationId : null;
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
      bookingProvider.fetchOrganizationBookings(organizationId, type: 'blood'),
      context.read<BloodProvider>().fetchStockForOrg(organizationId),
    ]);
    if (!_isCurrentScope(organizationId, capturedGeneration)) return;
    setState(() {
      _bookings = bookingProvider.bookings
          .where(
            (booking) =>
                booking.organizationId == organizationId &&
                booking.type == 'blood',
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
        auth.isBloodBankAdmin &&
        auth.user?.organizationId == organizationId;
  }

  Future<void> _approve(BookingRequestModel booking) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null || booking.organizationId != organizationId) {
      return;
    }
    try {
      final stock = context.read<BloodProvider>().getStockForOrg(
        organizationId,
      );
      final match = stock.firstWhere(
        (s) => booking.bloodStockId != null
            ? s.id == booking.bloodStockId
            : s.bloodType == booking.bloodType,
      );

      await context.read<BookingProvider>().confirmBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        resourceId: match.id,
        bookingType: 'blood',
        holdMinutes: 60,
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _loadRequests(generation: generation);
      if (!_isCurrentScope(organizationId, generation)) return;
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      final stock = context.read<BloodProvider>().getStockForOrg(
        organizationId,
      );
      final match = stock.firstWhere(
        (s) => booking.bloodStockId != null
            ? s.id == booking.bloodStockId
            : s.bloodType == booking.bloodType,
      );

      await context.read<BookingProvider>().admitBooking(
        bookingId: booking.id,
        organizationId: organizationId,
        resourceId: match.id,
        bookingType: 'blood',
      );
      if (!_isCurrentScope(organizationId, generation)) return;
      await _loadRequests(generation: generation);
      if (!_isCurrentScope(organizationId, generation)) return;
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                booking.type == 'blood',
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
                    'Blood Requests',
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
                    child: Text('No blood requests'),
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
                            PrescriptionDialogButton(
                              documentId: booking.prescriptionDocumentId,
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
