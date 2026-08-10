import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/booking_request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../shared/widgets/booking_status_chip.dart';
import '../../../shared/widgets/price_widget.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  Stream<List<BookingRequestModel>>? _bookingsStream;
  String? _streamUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthProvider>().user?.uid;
    if (userId != null && userId != _streamUserId) {
      _streamUserId = userId;
      _bookingsStream = context.read<BookingProvider>().watchUserBookings(
        userId,
      );
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'bed':
        return Icons.bed;
      case 'ambulance':
        return Icons.emergency;
      case 'blood':
        return Icons.bloodtype;
      case 'test':
        return Icons.science;
      default:
        return Icons.info;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bed':
        return 'Bed Booking';
      case 'ambulance':
        return 'Ambulance Booking';
      case 'blood':
        return 'Blood Request';
      case 'test':
        return 'Diagnostic Test Serial';
      default:
        return 'Booking';
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'bed':
        return Colors.blue;
      case 'ambulance':
        return Colors.orange;
      case 'blood':
        return Colors.red;
      case 'test':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bookingsStream == null) {
      return const Center(child: Text('Sign in to view your bookings'));
    }

    return StreamBuilder<List<BookingRequestModel>>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load live booking updates: ${snapshot.error}',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'My Bookings',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const _LiveIndicator(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (bookings.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No bookings yet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your booking requests will appear here',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...bookings.map(
                      (booking) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _typeColor(
                              booking.type,
                            ).withValues(alpha: 0.15),
                            child: Icon(
                              _typeIcon(booking.type),
                              color: _typeColor(booking.type),
                            ),
                          ),
                          title: Text(
                            booking.organizationName ??
                                '${_typeLabel(booking.type)} Booking',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _typeLabel(booking.type),
                                style: TextStyle(
                                  color: _typeColor(booking.type),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              if (booking.type == 'bed' &&
                                  booking.bedType != null)
                                Text('Bed Type: ${booking.bedType}'),
                              if (booking.type == 'blood' &&
                                  booking.bloodType != null)
                                Text(
                                  'Blood: ${booking.bloodType} - ${booking.unitsNeeded ?? 0} units',
                                ),
                              if (booking.type == 'ambulance' &&
                                  booking.ambulanceType != null)
                                Text('Ambulance: ${booking.ambulanceType}'),
                              if (booking.type == 'test')
                                Text(
                                  '${booking.testName ?? 'Diagnostic Test'} - Serial #${booking.serialNumber ?? '-'}',
                                ),
                              Text(
                                timeago.format(booking.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (booking.estimatedPrice != null)
                                PriceWidget(price: booking.estimatedPrice),
                              const SizedBox(width: 8),
                              BookingStatusChip(
                                status: booking.status,
                                bookingType: booking.type,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => context.go('/booking/${booking.id}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Text(
            'Live',
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
