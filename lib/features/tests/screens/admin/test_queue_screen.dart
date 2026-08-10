import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../models/test_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';
import '../../providers/test_provider.dart';

class TestQueueScreen extends StatefulWidget {
  final String testId;

  const TestQueueScreen({super.key, required this.testId});

  @override
  State<TestQueueScreen> createState() => _TestQueueScreenState();
}

class _TestQueueScreenState extends State<TestQueueScreen> {
  Stream<List<BookingRequestModel>>? _queueStream;
  String? _organizationId;
  String? _workingBookingId;

  @override
  void initState() {
    super.initState();
    _organizationId = context.read<AuthProvider>().user?.organizationId;
    final organizationId = _organizationId;
    if (organizationId != null) {
      context.read<TestProvider>().fetchTestsForOrg(organizationId);
      _queueStream = context.read<BookingProvider>().watchDiagnosticQueue(
        organizationId,
      );
    }
  }

  bool _isToday(BookingRequestModel booking) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 6));
    return booking.queueYear == now.year &&
        booking.queueMonth == now.month &&
        booking.queueDay == now.day;
  }

  Future<void> _runAction(
    BookingRequestModel booking,
    Future<void> Function() action,
  ) async {
    setState(() => _workingBookingId = booking.id);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _workingBookingId = null);
    }
  }

  Future<void> _confirmCancel(
    BookingRequestModel booking,
    BookingProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel serial #${booking.serialNumber}?'),
        content: Text(
          'This removes ${booking.patientName} from the active queue. The receipt will remain visible as cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Serial'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Serial'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runAction(
        booking,
        () => provider.cancelDiagnosticSerial(booking.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationId = _organizationId;
    if (organizationId == null || _queueStream == null) {
      return const Center(child: Text('No organization assigned'));
    }

    final tests = context.watch<TestProvider>().getTestsForOrg(organizationId);
    DiagnosticTestModel? test;
    for (final item in tests) {
      if (item.id == widget.testId) {
        test = item;
        break;
      }
    }

    return StreamBuilder<List<BookingRequestModel>>(
      stream: _queueStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load the live queue: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final testBookings = snapshot.data!
            .where((booking) => booking.testId == widget.testId)
            .toList();
        final queue =
            testBookings
                .where(
                  (booking) =>
                      _isToday(booking) ||
                      booking.isPending ||
                      booking.isConfirmed,
                )
                .toList()
              ..sort(
                (a, b) => (a.serialNumber ?? 0).compareTo(b.serialNumber ?? 0),
              );
        final waiting = queue.where((booking) => booking.isPending).toList();
        final called = queue.where((booking) => booking.isConfirmed).toList();
        final completed = queue.where((booking) => booking.isAdmitted).length;
        final todayTotal = testBookings.where(_isToday).length;
        final current = called.isEmpty ? null : called.first;
        final next = waiting.isEmpty ? null : waiting.first;
        final provider = context.read<BookingProvider>();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/admin/tests'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to diagnostic tests'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              test?.testName ?? 'Diagnostic Test Queue',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Today, ${DateFormat('d MMMM yyyy').format(DateTime.now().toUtc().add(const Duration(hours: 6)))} • Live updates',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            current != null ||
                                next == null ||
                                _workingBookingId != null
                            ? null
                            : () => _runAction(
                                next,
                                () => provider.callDiagnosticSerial(next.id),
                              ),
                        icon: const Icon(Icons.campaign),
                        label: Text(
                          current != null
                              ? 'Complete #${current.serialNumber} first'
                              : next == null
                              ? 'No one waiting'
                              : 'Call #${next.serialNumber}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QueueStat(
                        label: 'Serials Today',
                        value: '$todayTotal',
                        icon: Icons.confirmation_number,
                        color: Colors.purple,
                      ),
                      _QueueStat(
                        label: 'Waiting',
                        value: '${waiting.length}',
                        icon: Icons.people_alt_outlined,
                        color: Colors.orange,
                      ),
                      _QueueStat(
                        label: 'Currently Called',
                        value: current == null
                            ? '-'
                            : '#${current.serialNumber}',
                        icon: Icons.campaign_outlined,
                        color: Colors.blue,
                      ),
                      _QueueStat(
                        label: 'Completed',
                        value: '$completed',
                        icon: Icons.task_alt,
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (queue.isEmpty)
                    const _EmptyQueue()
                  else
                    ...queue.map(
                      (booking) => _SerialCard(
                        booking: booking,
                        isWorking: _workingBookingId == booking.id,
                        onComplete: booking.isConfirmed
                            ? () => _runAction(
                                booking,
                                () => provider.completeDiagnosticSerial(
                                  booking.id,
                                ),
                              )
                            : null,
                        onCancel:
                            booking.isConfirmed ||
                                (booking.isPending && booking.id == next?.id)
                            ? () => _confirmCancel(booking, provider)
                            : null,
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

class _QueueStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QueueStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(label, style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SerialCard extends StatelessWidget {
  final BookingRequestModel booking;
  final bool isWorking;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const _SerialCard({
    required this.booking,
    required this.isWorking,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: booking.isConfirmed ? Colors.blue.withValues(alpha: 0.07) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '#${booking.serialNumber ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(booking.contactNumber),
                    if (booking.estimatedArrivalTime != null)
                      Text(
                        'Estimated arrival: ${DateFormat('h:mm a').format(booking.estimatedArrivalTime!)}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    if (booking.calledAt != null)
                      Text(
                        'Called: ${DateFormat('d MMM yyyy, h:mm:ss a').format(booking.calledAt!)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (booking.completedAt != null)
                      Text(
                        'Completed: ${DateFormat('d MMM yyyy, h:mm:ss a').format(booking.completedAt!)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BookingStatusChip(
                status: booking.status,
                bookingType: booking.type,
              ),
              if (onComplete != null)
                FilledButton.icon(
                  onPressed: isWorking ? null : onComplete,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Complete'),
                ),
              if (onCancel != null)
                IconButton(
                  onPressed: isWorking ? null : onCancel,
                  tooltip: 'Cancel serial',
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
            ],
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: constraints.maxWidth < 650
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, const SizedBox(height: 12), actions],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No serials have been taken for this test today.'),
          ],
        ),
      ),
    );
  }
}
