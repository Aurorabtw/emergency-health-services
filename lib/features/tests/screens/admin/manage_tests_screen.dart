import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/booking_request_model.dart';
import '../../../../models/test_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/booking_provider.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/price_widget.dart';
import '../../providers/test_provider.dart';

class ManageTestsScreen extends StatefulWidget {
  const ManageTestsScreen({super.key});

  @override
  State<ManageTestsScreen> createState() => _ManageTestsScreenState();
}

class _ManageTestsScreenState extends State<ManageTestsScreen> {
  String? _orgId;
  Stream<List<BookingRequestModel>>? _queueStream;
  String? _scopeKey;
  bool _isScopeLoading = false;
  int _scopeGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final scopeKey = '${user?.uid}|${user?.role}|${user?.organizationId}';
    if (scopeKey == _scopeKey) return;
    _scopeKey = scopeKey;
    _orgId = auth.isTestAdmin ? user?.organizationId : null;
    _queueStream = _orgId == null
        ? null
        : context.read<BookingProvider>().watchDiagnosticQueue(_orgId!);
    _isScopeLoading = _orgId != null;
    final organizationId = _orgId;
    final generation = ++_scopeGeneration;
    if (organizationId != null) {
      Future.microtask(() => _loadScope(organizationId, generation));
    }
  }

  Future<void> _loadScope(String organizationId, int generation) async {
    if (!_isCurrentScope(organizationId, generation)) return;
    await Future.wait([
      context.read<TestProvider>().fetchTestsForOrg(organizationId),
      context.read<TestProvider>().fetchCatalog(),
    ]);
    if (!_isCurrentScope(organizationId, generation)) return;
    setState(() => _isScopeLoading = false);
  }

  bool _isCurrentScope(String organizationId, int generation) {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    return generation == _scopeGeneration &&
        _orgId == organizationId &&
        auth.isTestAdmin &&
        auth.user?.organizationId == organizationId;
  }

  Future<void> _showForm({DiagnosticTestModel? existing}) async {
    final organizationId = _orgId;
    final generation = _scopeGeneration;
    if (organizationId == null) return;
    final provider = context.read<TestProvider>();
    if (provider.catalog.isEmpty) {
      await provider.fetchCatalog();
      if (!_isCurrentScope(organizationId, generation)) return;
    }
    if (!_isCurrentScope(organizationId, generation)) return;
    showDialog(
      context: context,
      builder: (_) => _TestFormDialog(
        existing: existing,
        catalog: provider.catalog,
        onSave: (test) async {
          if (!_isCurrentScope(organizationId, generation)) return;
          await context.read<TestProvider>().saveTest(organizationId, test);
          if (!_isCurrentScope(organizationId, generation)) return;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) {
      return const Center(child: Text('No organization assigned'));
    }

    final testProvider = context.watch<TestProvider>();
    final tests = testProvider.getTestsForOrg(_orgId!);

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
                    'Manage Tests',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Test'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isScopeLoading || testProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (tests.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('No tests configured'),
                  ),
                )
              else
                StreamBuilder<List<BookingRequestModel>>(
                  stream: _queueStream,
                  builder: (context, snapshot) {
                    final bookings = snapshot.data ?? const [];
                    return Column(
                      children: [
                        if (snapshot.hasError)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              'Live queue unavailable: ${snapshot.error}',
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ...tests.map((test) {
                          final testBookings = bookings
                              .where((booking) => booking.testId == test.id)
                              .toList();
                          final waiting = testBookings
                              .where((booking) => booking.isPending)
                              .length;
                          final remaining =
                              (test.dailyCapacity - testBookings.length)
                                  .clamp(0, test.dailyCapacity)
                                  .toInt();
                          final hasActiveQueue = testBookings.any(
                            (booking) =>
                                booking.isPending || booking.isConfirmed,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              onTap: () =>
                                  context.push('/admin/tests/${test.id}/queue'),
                              leading: const CircleAvatar(
                                child: Icon(Icons.science),
                              ),
                              title: Text(
                                test.testName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  PriceWidget(price: test.price),
                                  if (test.turnaroundTime.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.timer,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      test.turnaroundTime,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  if (test.homeCollection) ...[
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.home,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Home',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  _QueueCountBadge(
                                    today: testBookings.length,
                                    waiting: waiting,
                                    remaining: remaining,
                                    capacity: test.dailyCapacity,
                                    available: test.isAvailable,
                                    isLive: snapshot.hasData,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit test',
                                    onPressed: () => _showForm(existing: test),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    tooltip: hasActiveQueue
                                        ? 'Complete today\'s queue before deleting'
                                        : 'Delete test',
                                    onPressed: hasActiveQueue
                                        ? null
                                        : () async {
                                            final organizationId = _orgId;
                                            final generation = _scopeGeneration;
                                            if (organizationId == null) return;
                                            final provider = context
                                                .read<TestProvider>();
                                            final confirm =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (dlgCtx) =>
                                                      AlertDialog(
                                                        title: const Text(
                                                          'Delete Test?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  dlgCtx,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  dlgCtx,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Delete',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                            if (!_isCurrentScope(
                                              organizationId,
                                              generation,
                                            ))
                                              return;
                                            if (confirm == true) {
                                              try {
                                                await provider.deleteTest(
                                                  organizationId,
                                                  test.id,
                                                );
                                                if (!_isCurrentScope(
                                                  organizationId,
                                                  generation,
                                                ))
                                                  return;
                                              } catch (e) {
                                                if (!_isCurrentScope(
                                                  organizationId,
                                                  generation,
                                                ))
                                                  return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      _testOperationError(e),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueCountBadge extends StatelessWidget {
  final int today;
  final int waiting;
  final int remaining;
  final int capacity;
  final bool available;
  final bool isLive;

  const _QueueCountBadge({
    required this.today,
    required this.waiting,
    required this.remaining,
    required this.capacity,
    required this.available,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (available ? Colors.purple : Colors.red).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        !available
            ? 'Unavailable'
            : isLive
            ? '$remaining/$capacity available • $waiting waiting'
            : 'Connecting queue...',
        style: TextStyle(
          color: available ? Colors.purple.shade700 : Colors.red.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TestFormDialog extends StatefulWidget {
  final DiagnosticTestModel? existing;
  final List<DiagnosticTestCatalogModel> catalog;
  final Future<void> Function(DiagnosticTestModel) onSave;

  const _TestFormDialog({
    this.existing,
    required this.catalog,
    required this.onSave,
  });

  @override
  State<_TestFormDialog> createState() => _TestFormDialogState();
}

class _TestFormDialogState extends State<_TestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _turnaroundController = TextEditingController();
  final _surchargeController = TextEditingController();
  final _slotDurationController = TextEditingController();
  final _dailyCapacityController = TextEditingController();
  String? _selectedCatalogId;
  bool _homeCollection = false;
  bool _isAvailable = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.testName ?? '';
    _selectedCatalogId = widget.existing?.catalogTestId;
    if (_selectedCatalogId == null && widget.existing != null) {
      for (final catalogTest in widget.catalog) {
        if (catalogTest.normalizedName ==
            widget.existing!.testName.trim().toLowerCase()) {
          _selectedCatalogId = catalogTest.id;
          break;
        }
      }
    }
    _priceController.text = widget.existing?.price.toString() ?? '';
    _turnaroundController.text = widget.existing?.turnaroundTime ?? '';
    _homeCollection = widget.existing?.homeCollection ?? false;
    _surchargeController.text =
        widget.existing?.homeCollectionSurcharge?.toString() ?? '';
    _slotDurationController.text =
        widget.existing?.slotDurationMinutes.toString() ?? '15';
    _dailyCapacityController.text =
        widget.existing?.dailyCapacity.toString() ?? '100';
    _isAvailable = widget.existing?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _turnaroundController.dispose();
    _surchargeController.dispose();
    _slotDurationController.dispose();
    _dailyCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Test' : 'Add Test'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedCatalogId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Test Name',
                    helperText: 'Managed by the platform super admin',
                  ),
                  items: widget.catalog
                      .where(
                        (test) => test.active || test.id == _selectedCatalogId,
                      )
                      .map(
                        (test) => DropdownMenuItem(
                          value: test.id,
                          child: Text(test.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCatalogId = value);
                    final selected = widget.catalog
                        .where((test) => test.id == value)
                        .firstOrNull;
                    _nameController.text = selected?.name ?? '';
                  },
                  validator: (value) => value == null
                      ? 'Select a test from the master catalog'
                      : null,
                ),
                if (widget.catalog.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No tests are available. Ask the super admin to add tests to the master catalog.',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Available for Patient Serials'),
                  subtitle: const Text(
                    'Turn this off to stop new orders immediately.',
                  ),
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value),
                  contentPadding: EdgeInsets.zero,
                ),
                TextFormField(
                  controller: _dailyCapacityController,
                  decoration: const InputDecoration(
                    labelText: 'Daily Test Capacity',
                    helperText: 'Automatically resets each new Dhaka day',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final capacity = int.tryParse(value?.trim() ?? '');
                    if (capacity == null ||
                        capacity <= 0 ||
                        capacity > 100000) {
                      return 'Capacity must be a whole number from 1 to 100000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (৳)',
                    prefixText: '৳ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      Validators.validatePositiveNumber(v, 'Price'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _turnaroundController,
                  decoration: const InputDecoration(
                    labelText: 'Turnaround Time (e.g., "24 hours")',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slotDurationController,
                  decoration: const InputDecoration(
                    labelText: 'Average Queue Slot (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final minutes = int.tryParse(value?.trim() ?? '');
                    if (minutes == null || minutes <= 0 || minutes > 240) {
                      return 'Queue slot must be a whole number from 1 to 240';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Home Collection Available'),
                  value: _homeCollection,
                  onChanged: (v) => setState(() => _homeCollection = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_homeCollection)
                  TextFormField(
                    controller: _surchargeController,
                    decoration: const InputDecoration(
                      labelText: 'Home Collection Surcharge (৳, optional)',
                      prefixText: '৳ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isLoading = true);
                  try {
                    final catalogTest = widget.catalog
                        .where((test) => test.id == _selectedCatalogId)
                        .first;
                    final test = DiagnosticTestModel(
                      id: widget.existing?.id ?? '',
                      organizationId: widget.existing?.organizationId ?? '',
                      catalogTestId: catalogTest.id,
                      testName: catalogTest.name,
                      price: double.parse(_priceController.text),
                      turnaroundTime: _turnaroundController.text.trim(),
                      homeCollection: _homeCollection,
                      homeCollectionSurcharge:
                          _surchargeController.text.isNotEmpty
                          ? double.parse(_surchargeController.text)
                          : null,
                      slotDurationMinutes: int.parse(
                        _slotDurationController.text,
                      ),
                      isAvailable: _isAvailable,
                      dailyCapacity: int.parse(_dailyCapacityController.text),
                    );
                    await widget.onSave(test);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_testOperationError(e))),
                      );
                    }
                  }
                  if (mounted) setState(() => _isLoading = false);
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

String _testOperationError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Your current role is not recognized by the deployed Firestore rules. Deploy the updated rules, or temporarily assign Hospital Admin (Legacy).';
  }
  return 'Unable to update diagnostic tests: $error';
}
