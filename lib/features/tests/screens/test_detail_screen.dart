import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/organization_model.dart';
import '../../../models/test_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/profile_completion_dialog.dart';
import '../../../shared/widgets/price_widget.dart';
import '../providers/test_provider.dart';

class TestDetailScreen extends StatefulWidget {
  final String organizationId;
  final String testId;

  const TestDetailScreen({
    super.key,
    required this.organizationId,
    required this.testId,
  });

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  OrganizationModel? _organization;
  DiagnosticTestModel? _test;
  bool _isLoading = true;
  bool _isTakingSerial = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final organizationProvider = context.read<OrganizationProvider>();
    final testProvider = context.read<TestProvider>();
    final results = await Future.wait([
      organizationProvider.getOrganization(widget.organizationId),
      testProvider.fetchTestsForOrg(widget.organizationId),
    ]);
    if (!mounted) return;

    final organization = results[0] as OrganizationModel?;
    final tests = results[1] as List<DiagnosticTestModel>;
    final test = tests.where((item) => item.id == widget.testId).firstOrNull;
    setState(() {
      _organization = organization;
      _test = test;
      _isLoading = false;
      if (organization == null || test == null) {
        _error = 'This diagnostic test is no longer available.';
      }
    });
  }

  Future<void> _openUri(Uri uri, String failureMessage) async {
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tests');
    }
  }

  Future<void> _takeSerial() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final returnPath = '/tests/${widget.organizationId}/${widget.testId}';
      context.go('/login?redirect=${Uri.encodeComponent(returnPath)}');
      return;
    }

    final profileComplete = await ProfileCompletionDialog.showIfNeeded(context);
    if (!mounted || !profileComplete) return;

    final user = context.read<AuthProvider>().user;
    final organization = _organization;
    final test = _test;
    if (user == null || organization == null || test == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Take diagnostic serial?'),
        content: Text(
          'You will receive today\'s next serial for ${test.testName} at '
          '${organization.name}. Each queue slot is approximately '
          '${test.slotDurationMinutes} minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Get Serial'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isTakingSerial = true);
    try {
      final bookingId = await context
          .read<BookingProvider>()
          .createDiagnosticSerial(
            organizationId: organization.id,
            organizationName: organization.name,
            userId: user.uid,
            patientName: user.name ?? user.email,
            contactNumber: user.phone ?? '',
            testId: test.id,
          );
      if (mounted) context.go('/booking/$bookingId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isTakingSerial = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _organization == null || _test == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(_error ?? 'Diagnostic test not found'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to test search'),
              ),
            ],
          ),
        ),
      );
    }

    final organization = _organization!;
    final test = _test!;
    final directionsUri = Uri.https('www.openstreetmap.org', '/directions', {
      'to': '${organization.latitude},${organization.longitude}',
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to results'),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.science,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Diagnostic Test',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  test.testName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  organization.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          PriceWidget(price: test.price, prominent: true),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeading(
                            icon: Icons.fact_check_outlined,
                            title: 'Test information',
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Price',
                            value: '৳${test.price.toStringAsFixed(0)}',
                          ),
                          _DetailRow(
                            label: 'Turnaround time',
                            value: test.turnaroundTime.isEmpty
                                ? 'Contact hospital'
                                : test.turnaroundTime,
                          ),
                          _DetailRow(
                            label: 'Average queue slot',
                            value: '${test.slotDurationMinutes} minutes',
                          ),
                          _DetailRow(
                            label: 'Serial availability',
                            value: test.isAvailable
                                ? 'Available (${test.dailyCapacity} per day)'
                                : 'Currently unavailable',
                            valueColor: test.isAvailable
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          _DetailRow(
                            label: 'Home collection',
                            value: test.homeCollection
                                ? 'Available'
                                : 'Not available',
                            valueColor: test.homeCollection
                                ? Colors.green.shade700
                                : null,
                          ),
                          if (test.homeCollection &&
                              test.homeCollectionSurcharge != null)
                            _DetailRow(
                              label: 'Home surcharge',
                              value:
                                  '৳${test.homeCollectionSurcharge!.toStringAsFixed(0)}',
                            ),
                          const Divider(height: 36),
                          const _SectionHeading(
                            icon: Icons.local_hospital_outlined,
                            title: 'Hospital information',
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Hospital',
                            value: organization.name,
                          ),
                          _DetailRow(
                            label: 'Address',
                            value: organization.address,
                          ),
                          _DetailRow(label: 'Phone', value: organization.phone),
                          if (organization.email?.trim().isNotEmpty == true)
                            _DetailRow(
                              label: 'Email',
                              value: organization.email!,
                            ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avoid waiting at the hospital',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Take today\'s next serial to receive a live receipt and estimated arrival time.',
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed:
                                      _isTakingSerial || !test.isAvailable
                                      ? null
                                      : _takeSerial,
                                  icon: _isTakingSerial
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.confirmation_number),
                                  label: Text(
                                    _isTakingSerial
                                        ? 'Issuing serial...'
                                        : !test.isAvailable
                                        ? 'Currently Unavailable'
                                        : 'Take Serial',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: organization.phone.trim().isEmpty
                                    ? null
                                    : () => _openUri(
                                        Uri(
                                          scheme: 'tel',
                                          path: organization.phone,
                                        ),
                                        'Unable to open the phone application.',
                                      ),
                                icon: const Icon(Icons.phone),
                                label: Text('Call ${organization.phone}'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openUri(
                                  directionsUri,
                                  'Unable to open directions.',
                                ),
                                icon: const Icon(Icons.directions),
                                label: const Text('Get directions'),
                              ),
                              if (organization.email?.trim().isNotEmpty == true)
                                OutlinedButton.icon(
                                  onPressed: () => _openUri(
                                    Uri(
                                      scheme: 'mailto',
                                      path: organization.email,
                                    ),
                                    'Unable to open the email application.',
                                  ),
                                  icon: const Icon(Icons.email_outlined),
                                  label: const Text('Email hospital'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeading({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
