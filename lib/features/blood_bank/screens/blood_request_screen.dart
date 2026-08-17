import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/booking_request_model.dart';
import '../../../models/organization_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/prescription_upload_field.dart';
import '../../../shared/widgets/price_widget.dart';
import '../../../shared/widgets/profile_completion_dialog.dart';
import '../providers/blood_provider.dart';

class BloodRequestScreen extends StatefulWidget {
  final String organizationId;

  const BloodRequestScreen({super.key, required this.organizationId});

  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _doctorController = TextEditingController();
  final _unitsController = TextEditingController(text: '1');
  OrganizationModel? _org;
  String? _selectedStockId;
  OrganizationModel? _selectedHospital;
  List<OrganizationModel> _hospitals = [];
  Uint8List? _prescriptionImage;
  String _prescriptionContentType = 'image/jpeg';
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant BloodRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final organizationId = widget.organizationId;
    final generation = ++_loadGeneration;
    setState(() {
      _org = null;
      _selectedStockId = null;
      _selectedHospital = null;
      _hospitals = [];
      _prescriptionImage = null;
      _isLoading = true;
      _isSubmitting = false;
    });

    final auth = context.read<AuthProvider>();
    _nameController.text = auth.user?.name ?? '';
    _phoneController.text = auth.user?.phone ?? '';

    final orgProvider = context.read<OrganizationProvider>();
    final org = await orgProvider.getOrganization(organizationId);
    if (!mounted ||
        generation != _loadGeneration ||
        widget.organizationId != organizationId) {
      return;
    }
    await context.read<BloodProvider>().fetchStockForOrg(organizationId);
    if (!mounted ||
        generation != _loadGeneration ||
        widget.organizationId != organizationId) {
      return;
    }
    final hospitals = await orgProvider.getVerifiedByType('hospital');
    if (!mounted ||
        generation != _loadGeneration ||
        widget.organizationId != organizationId) {
      return;
    }

    setState(() {
      _org = org;
      _hospitals = hospitals;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    final organizationId = widget.organizationId;
    final generation = _loadGeneration;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }
    final userId = auth.user!.uid;

    final profileOk = await ProfileCompletionDialog.showIfNeeded(context);
    if (!mounted ||
        generation != _loadGeneration ||
        widget.organizationId != organizationId ||
        context.read<AuthProvider>().user?.uid != userId ||
        !profileOk) {
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = auth.user?.name ?? '';
    }
    if (_phoneController.text.trim().isEmpty) {
      _phoneController.text = auth.user?.phone ?? '';
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final bookingProvider = context.read<BookingProvider>();
      final bloodProvider = context.read<BloodProvider>();
      final stock = bloodProvider.getStockForOrg(organizationId);
      final match = stock.where((s) => s.id == _selectedStockId).firstOrNull;
      if (match == null) throw StateError('Select an available blood type.');
      final units = int.parse(_unitsController.text);
      if (units > match.availableUnits) {
        throw StateError(
          'Only ${match.availableUnits} units are currently available.',
        );
      }
      final estimatedPrice = match.processingFeePerUnit * units;
      final bookingId = bookingProvider.generateBookingId();

      final booking = BookingRequestModel(
        id: bookingId,
        type: 'blood',
        organizationId: organizationId,
        organizationName: _org?.name,
        userId: userId,
        patientName: _nameController.text.trim(),
        contactNumber: Validators.normalizePhone(_phoneController.text),
        createdAt: DateTime.now(),
        bloodStockId: match.id,
        bloodType: match.bloodType,
        unitsNeeded: units,
        hospitalId: _selectedHospital?.id,
        hospitalName: _selectedHospital?.name,
        prescribingDoctor: _doctorController.text.trim(),
        prescriptionDocumentId: bookingId,
        estimatedPrice: estimatedPrice,
      );

      await bookingProvider.createBookingWithPrescription(
        booking,
        _prescriptionImage!,
        contentType: _prescriptionContentType,
      );
      if (!mounted ||
          generation != _loadGeneration ||
          widget.organizationId != organizationId ||
          context.read<AuthProvider>().user?.uid != userId) {
        return;
      }
      context.go('/booking/${booking.id}');
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          widget.organizationId == organizationId &&
          context.read<AuthProvider>().user?.uid == userId) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }

    if (mounted &&
        generation == _loadGeneration &&
        widget.organizationId == organizationId &&
        context.read<AuthProvider>().user?.uid == userId) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _doctorController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloodProvider = context.watch<BloodProvider>();
    final stock = bloodProvider.getStockForOrg(widget.organizationId);

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_org == null)
      return const Center(child: Text('Organization not found'));

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
                    Text(
                      'Blood Request',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _org!.name,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(height: 32),
                    DropdownButtonFormField<String>(
                      key: ValueKey('blood-type-${widget.organizationId}'),
                      initialValue: _selectedStockId,
                      decoration: const InputDecoration(
                        labelText: 'Blood Type',
                        prefixIcon: Icon(Icons.bloodtype),
                      ),
                      items: stock.where((item) => item.availableUnits > 0).map(
                        (s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(s.bloodType),
                                Text(
                                  '${s.availableUnits} units',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (v) => setState(() => _selectedStockId = v),
                      validator: (v) => v == null ? 'Select blood type' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitsController,
                      decoration: const InputDecoration(
                        labelText: 'Units Needed',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final base = Validators.validatePositiveInt(v, 'Units');
                        if (base != null) return base;
                        final selected = stock
                            .where((item) => item.id == _selectedStockId)
                            .firstOrNull;
                        if (selected == null)
                          return 'Select an available blood type';
                        return int.parse(v!) > selected.availableUnits
                            ? 'Only ${selected.availableUnits} units are available'
                            : null;
                      },
                    ),
                    if (_selectedStockId != null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final s = stock
                              .where((s) => s.id == _selectedStockId)
                              .firstOrNull;
                          if (s == null) return const SizedBox.shrink();
                          final units =
                              int.tryParse(_unitsController.text) ?? 1;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                PriceWidget(
                                  price: s.processingFeePerUnit,
                                  label: 'unit',
                                ),
                                EstimatedPriceWidget(
                                  price: s.processingFeePerUnit * units,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: Validators.validatePhone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('hospital-${widget.organizationId}'),
                      initialValue: _selectedHospital?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hospital Where Blood is Needed',
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                      hint: const Text('Select a hospital'),
                      items: _hospitals
                          .map(
                            (h) => DropdownMenuItem<String>(
                              value: h.id,
                              child: Text(
                                h.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) => setState(() {
                        _selectedHospital = id == null
                            ? null
                            : _hospitals.firstWhere((h) => h.id == id);
                      }),
                      validator: (v) => v == null ? 'Select a hospital' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _doctorController,
                      decoration: const InputDecoration(
                        labelText: 'Prescribing Doctor',
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                      validator: (v) =>
                          Validators.validateRequired(v, 'Doctor name'),
                    ),
                    const SizedBox(height: 16),
                    PrescriptionUploadField(
                      key: ValueKey('prescription-${widget.organizationId}'),
                      onChanged: (bytes, _, contentType) => setState(() {
                        _prescriptionImage = bytes;
                        _prescriptionContentType = contentType;
                      }),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit Blood Request'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The blood bank will verify your request and call you before confirming.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
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
