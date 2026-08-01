import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/booking_request_model.dart';
import '../../../models/organization_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/price_widget.dart';
import '../../../shared/widgets/profile_completion_dialog.dart';
import '../providers/ambulance_provider.dart';

class AmbulanceBookingScreen extends StatefulWidget {
  final String organizationId;

  const AmbulanceBookingScreen({super.key, required this.organizationId});

  @override
  State<AmbulanceBookingScreen> createState() => _AmbulanceBookingScreenState();
}

class _AmbulanceBookingScreenState extends State<AmbulanceBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pickupController = TextEditingController();
  final _notesController = TextEditingController();
  OrganizationModel? _operator;
  String? _selectedType;
  String? _selectedDestination;
  List<OrganizationModel> _hospitals = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    _nameController.text = auth.user?.name ?? '';
    _phoneController.text = auth.user?.phone ?? '';

    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.hasLocation) {
      _pickupController.text = 'Current Location (${locationProvider.latitude!.toStringAsFixed(4)}, ${locationProvider.longitude!.toStringAsFixed(4)})';
    }

    final orgProvider = context.read<OrganizationProvider>();
    final org = await orgProvider.getOrganization(widget.organizationId);
    await context.read<AmbulanceProvider>().fetchAmbulancesForOrg(widget.organizationId);
    final hospitals = await orgProvider.getVerifiedByType('hospital');

    if (mounted) setState(() { _operator = org; _hospitals = hospitals; _isLoading = false; });
  }

  double? _estimateFare() {
    if (_selectedType == null) return null;
    final ambulances = context.read<AmbulanceProvider>().getAmbulancesForOrg(widget.organizationId);
    final match = ambulances.where((a) => a.type == _selectedType).firstOrNull;
    if (match == null) return null;
    return match.baseFare;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.go('/login'); return; }

    final profileOk = await ProfileCompletionDialog.showIfNeeded(context);
    if (!profileOk) return;

    setState(() => _isSubmitting = true);

    try {
      final locationProvider = context.read<LocationProvider>();

      final booking = BookingRequestModel(
        id: '',
        type: 'ambulance',
        organizationId: widget.organizationId,
        organizationName: _operator?.name,
        userId: auth.user!.uid,
        patientName: _nameController.text.trim(),
        contactNumber: _phoneController.text.trim(),
        createdAt: DateTime.now(),
        ambulanceType: _selectedType,
        pickupLat: locationProvider.latitude,
        pickupLng: locationProvider.longitude,
        pickupAddress: _pickupController.text.trim(),
        destinationAddress: _selectedDestination,
        patientConditionNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        estimatedPrice: _estimateFare(),
      );

      final bookingId = await context.read<BookingProvider>().createBooking(booking);
      if (mounted) context.go('/booking/$bookingId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pickupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ambProvider = context.watch<AmbulanceProvider>();
    final ambulances = ambProvider.getAmbulancesForOrg(widget.organizationId);
    final available = ambulances.where((a) => a.isAvailable).toList();

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_operator == null) return const Center(child: Text('Operator not found'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Book Ambulance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_operator!.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    const Divider(height: 32),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Ambulance Type', prefixIcon: Icon(Icons.emergency)),
                      items: available.map((a) {
                        return DropdownMenuItem(
                          value: a.type,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(a.type),
                              PriceWidget(price: a.baseFare, label: 'base'),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedType = v),
                      validator: (v) => v == null ? 'Select type' : null,
                    ),
                    if (_selectedType != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Text('Estimated fare: '),
                            EstimatedPriceWidget(price: _estimateFare()),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pickupController,
                      decoration: const InputDecoration(labelText: 'Pickup Location', prefixIcon: Icon(Icons.my_location)),
                      validator: (v) => Validators.validateRequired(v, 'Pickup location'),
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<OrganizationModel>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable.empty();
                        final query = textEditingValue.text.toLowerCase();
                        return _hospitals.where((h) =>
                          h.name.toLowerCase().contains(query) ||
                          h.address.toLowerCase().contains(query)
                        );
                      },
                      displayStringForOption: (org) => org.name,
                      onSelected: (org) => _selectedDestination = org.name,
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Destination Hospital (optional)',
                            prefixIcon: Icon(Icons.local_hospital),
                            hintText: 'Search hospitals...',
                          ),
                          onChanged: (value) {
                            if (value.isEmpty) _selectedDestination = null;
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 552),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final org = options.elementAt(index);
                                  return ListTile(
                                    leading: const Icon(Icons.local_hospital, size: 20),
                                    title: Text(org.name),
                                    subtitle: org.address.isNotEmpty ? Text(org.address, overflow: TextOverflow.ellipsis, maxLines: 1) : null,
                                    onTap: () => onSelected(org),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Patient Name', prefixIcon: Icon(Icons.person)),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Contact Number', prefixIcon: Icon(Icons.phone)),
                      validator: Validators.validatePhone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Patient Condition Notes (optional)', prefixIcon: Icon(Icons.notes)),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Ambulance Request'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The operator will confirm your trip and contact you with details.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
