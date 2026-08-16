import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/widgets/booking_status_chip.dart';

class DiagnosticQueueOverviewScreen extends StatefulWidget {
  final String initialStatus;

  const DiagnosticQueueOverviewScreen({
    super.key,
    this.initialStatus = 'waiting',
  });

  @override
  State<DiagnosticQueueOverviewScreen> createState() =>
      _DiagnosticQueueOverviewScreenState();
}

class _DiagnosticQueueOverviewScreenState
    extends State<DiagnosticQueueOverviewScreen> {
  Stream<List<BookingRequestModel>>? _queueStream;
  late String _status;
  String? _workingBookingId;
  String? _organizationId;
  String? _scopeKey;
  int _scopeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _status = _validStatus(widget.initialStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final scopeKey = '${user?.uid}|${user?.role}|${user?.organizationId}';
    if (scopeKey == _scopeKey) return;
    _scopeKey = scopeKey;
    _organizationId = auth.isTestAdmin ? user?.organizationId : null;
    _workingBookingId = null;
    ++_scopeGeneration;
    _queueStream = _organizationId == null
        ? null
        : context.read<BookingProvider>().watchDiagnosticQueue(
            _organizationId!,
          );
  }

  @override
  void didUpdateWidget(covariant DiagnosticQueueOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      _status = _validStatus(widget.initialStatus);
    }
  }

  String _validStatus(String value) {
    return const {'waiting', 'called', 'completed'}.contains(value)
        ? value
        : 'waiting';
  }

  void _selectStatus(String status) {
    if (_status == status) return;
    setState(() => _status = status);
    context.replace('/admin/test-queue?status=$status');
  }

  Future<void> _runAction(
    BookingRequestModel booking,
    Future<void> Function() action,
  ) async {
    final organizationId = _organizationId;
    final generation = _scopeGeneration;
    if (organizationId == null ||
        booking.organizationId != organizationId ||
        !_isCurrentScope(organizationId, generation)) {
      return;
    }
    setState(() => _workingBookingId = booking.id);
    try {
      await action();
      if (!_isCurrentScope(organizationId, generation)) return;
    } catch (e) {
      if (_isCurrentScope(organizationId, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (_isCurrentScope(organizationId, generation)) {
        setState(() => _workingBookingId = null);
      }
    }
  }

  bool _isCurrentScope(String organizationId, int generation) {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    return generation == _scopeGeneration &&
        _organizationId == organizationId &&
        auth.isTestAdmin &&
        auth.user?.organizationId == organizationId;
  }

  @override
  Widget build(BuildContext context) {
    final queueStream = _queueStream;
    if (queueStream == null) {
      return const Center(child: Text('No organization assigned'));
    }

    return StreamBuilder<List<BookingRequestModel>>(
      key: ValueKey('$_organizationId:$_scopeGeneration'),
      stream: queueStream,
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

        final bookings = snapshot.data!;
        final waiting = bookings.where((booking) => booking.isPending).toList();
        final called = bookings
            .where((booking) => booking.isConfirmed)
            .toList();
        final completed = bookings
            .where((booking) => booking.isAdmitted)
            .toList();
        final visible = switch (_status) {
          'called' => called,
          'completed' => completed,
          _ => waiting,
        };

        if (_status == 'completed') {
          visible.sort(
            (a, b) => (b.completedAt ?? b.createdAt).compareTo(
              a.completedAt ?? a.createdAt,
            ),
          );
        } else {
          visible.sort(
            (a, b) => (a.serialNumber ?? 0).compareTo(b.serialNumber ?? 0),
          );
        }

        final activeByTest = <String, BookingRequestModel>{
          for (final booking in called)
            if (booking.testId != null) booking.testId!: booking,
        };
        final nextByTest = <String, BookingRequestModel>{};
        for (final booking in waiting) {
          final testId = booking.testId;
          if (testId == null) continue;
          final current = nextByTest[testId];
          if (current == null ||
              (booking.serialNumber ?? 0) < (current.serialNumber ?? 0)) {
            nextByTest[testId] = booking;
          }
        }
        final provider = context.read<BookingProvider>();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnostic Queue',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Live patient serials and test progress',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 10),
                      const _LiveBadge(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FilterStat(
                        label: 'Waiting',
                        value: waiting.length,
                        icon: Icons.people_alt_outlined,
                        color: Colors.orange,
                        selected: _status == 'waiting',
                        onTap: () => _selectStatus('waiting'),
                      ),
                      _FilterStat(
                        label: 'Called',
                        value: called.length,
                        icon: Icons.campaign_outlined,
                        color: Colors.blue,
                        selected: _status == 'called',
                        onTap: () => _selectStatus('called'),
                      ),
                      _FilterStat(
                        label: 'Completed',
                        value: completed.length,
                        icon: Icons.task_alt,
                        color: Colors.green,
                        selected: _status == 'completed',
                        onTap: () => _selectStatus('completed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    switch (_status) {
                      'called' => 'Called Patients',
                      'completed' => 'Completed Tests',
                      _ => 'Waiting Patients',
                    },
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    _EmptyStatus(status: _status)
                  else
                    ...visible.map((booking) {
                      final isNext =
                          nextByTest[booking.testId]?.id == booking.id;
                      final hasActive = activeByTest.containsKey(
                        booking.testId,
                      );
                      return _OverviewQueueCard(
                        booking: booking,
                        isWorking: _workingBookingId == booking.id,
                        onOpen: () => context.push('/booking/${booking.id}'),
                        onManageTest: booking.testId == null
                            ? null
                            : () => context.push(
                                '/admin/tests/${booking.testId}/queue',
                              ),
                        onCall: booking.isPending && isNext && !hasActive
                            ? () => _runAction(
                                booking,
                                () => provider.callDiagnosticSerial(booking.id),
                              )
                            : null,
                        onComplete: booking.isConfirmed
                            ? () => _runAction(
                                booking,
                                () => provider.completeDiagnosticSerial(
                                  booking.id,
                                ),
                              )
                            : null,
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: selected ? 0.16 : 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : color.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                        '$value',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(label),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewQueueCard extends StatelessWidget {
  final BookingRequestModel booking;
  final bool isWorking;
  final VoidCallback onOpen;
  final VoidCallback? onManageTest;
  final VoidCallback? onCall;
  final VoidCallback? onComplete;

  const _OverviewQueueCard({
    required this.booking,
    required this.isWorking,
    required this.onOpen,
    required this.onManageTest,
    required this.onCall,
    required this.onComplete,
  });

  String? get _timestamp {
    final time = booking.isConfirmed
        ? booking.calledAt
        : booking.isAdmitted
        ? booking.completedAt
        : null;
    if (time == null) return null;
    return DateFormat('d MMM yyyy, h:mm:ss a').format(time);
  }

  @override
  Widget build(BuildContext context) {
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
                booking.testName ?? 'Diagnostic Test',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${booking.patientName} • ${booking.contactNumber}'),
              if (booking.estimatedArrivalTime != null)
                Text(
                  'Estimated arrival: ${DateFormat('d MMM, h:mm a').format(booking.estimatedArrivalTime!)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              if (_timestamp != null)
                Text(
                  '${booking.isConfirmed ? 'Called' : 'Completed'}: $_timestamp',
                  style: TextStyle(
                    color: booking.isConfirmed
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
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
        BookingStatusChip(status: booking.status, bookingType: booking.type),
        if (onCall != null)
          FilledButton.icon(
            onPressed: isWorking ? null : onCall,
            icon: const Icon(Icons.campaign),
            label: const Text('Mark Called'),
          ),
        if (onComplete != null)
          FilledButton.icon(
            onPressed: isWorking ? null : onComplete,
            icon: const Icon(Icons.task_alt),
            label: const Text('Mark Completed'),
          ),
        IconButton(
          onPressed: onManageTest,
          tooltip: 'Open test queue',
          icon: const Icon(Icons.list_alt),
        ),
        IconButton(
          onPressed: onOpen,
          tooltip: 'Open receipt',
          icon: const Icon(Icons.receipt_long),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: booking.isConfirmed ? Colors.blue.withValues(alpha: 0.06) : null,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: constraints.maxWidth < 720
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
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'LIVE',
        style: TextStyle(
          color: Colors.green.shade700,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyStatus extends StatelessWidget {
  final String status;

  const _EmptyStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Text(switch (status) {
          'called' => 'No patients are currently called.',
          'completed' => 'No diagnostic tests have been completed.',
          _ => 'No patients are waiting.',
        }),
      ),
    );
  }
}
