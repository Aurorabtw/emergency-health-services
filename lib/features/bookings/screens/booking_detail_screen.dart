import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/booking_request_model.dart';
import '../../../providers/booking_provider.dart';
import '../../../shared/widgets/booking_status_chip.dart';
import '../../../shared/widgets/price_widget.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  BookingRequestModel? _booking;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bed': return 'Bed Booking';
      case 'ambulance': return 'Ambulance Booking';
      case 'blood': return 'Blood Request';
      default: return 'Booking';
    }
  }

  Future<void> _loadBooking() async {
    final booking = await context.read<BookingProvider>().getBooking(widget.bookingId);
    if (mounted) {
      setState(() {
        _booking = booking;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_booking == null) {
      return const Center(child: Text('Booking not found'));
    }

    final booking = _booking!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_typeLabel(booking.type)} Details',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      BookingStatusChip(status: booking.status),
                    ],
                  ),
                  const Divider(height: 32),
                  if (booking.organizationName != null)
                    _DetailRow(label: 'Organization', value: booking.organizationName!),
                  _DetailRow(label: 'Patient Name', value: booking.patientName),
                  _DetailRow(label: 'Contact', value: booking.contactNumber),
                  if (booking.estimatedPrice != null)
                    _DetailRowWidget(
                      label: 'Estimated Price',
                      child: PriceWidget(price: booking.estimatedPrice, prominent: true),
                    ),
                  if (booking.type == 'bed') ...[
                    _DetailRow(label: 'Bed Type', value: booking.bedType ?? '-'),
                  ],
                  if (booking.type == 'ambulance') ...[
                    _DetailRow(label: 'Ambulance Type', value: booking.ambulanceType ?? '-'),
                    if (booking.patientConditionNotes != null)
                      _DetailRow(label: 'Condition Notes', value: booking.patientConditionNotes!),
                    if (booking.pickupAddress != null)
                      _DetailRow(label: 'Pickup', value: booking.pickupAddress!),
                    if (booking.destinationAddress != null)
                      _DetailRow(label: 'Destination', value: booking.destinationAddress!),
                  ],
                  if (booking.type == 'blood') ...[
                    _DetailRow(label: 'Blood Type', value: booking.bloodType ?? '-'),
                    _DetailRow(label: 'Units Needed', value: '${booking.unitsNeeded ?? 0}'),
                    _DetailRow(label: 'Hospital', value: booking.hospitalName ?? '-'),
                    _DetailRow(label: 'Prescribing Doctor', value: booking.prescribingDoctor ?? '-'),
                  ],
                  if (booking.isConfirmed && booking.heldUntil != null) ...[
                    const Divider(height: 32),
                    _HoldCountdown(heldUntil: booking.heldUntil!),
                  ],
                  const Divider(height: 32),
                  _DetailRow(label: 'Created', value: booking.createdAt.toString().split('.').first),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _DetailRowWidget extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRowWidget({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          child,
        ],
      ),
    );
  }
}

class _HoldCountdown extends StatelessWidget {
  final DateTime heldUntil;

  const _HoldCountdown({required this.heldUntil});

  @override
  Widget build(BuildContext context) {
    final remaining = heldUntil.difference(DateTime.now());
    final isExpired = remaining.isNegative;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.timer_off : Icons.timer,
            color: isExpired ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 12),
          Text(
            isExpired
                ? 'Hold has expired'
                : 'Hold expires in ${remaining.inMinutes} min ${remaining.inSeconds % 60} sec',
            style: TextStyle(
              color: isExpired ? Colors.red.shade700 : Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
