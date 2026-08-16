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
import '../providers/bed_provider.dart';

class BedBookingScreen extends StatefulWidget {
  final String organizationId;

  const BedBookingScreen({super.key, required this.organizationId});

  @override
  State<BedBookingScreen> createState() => _BedBookingScreenState();
}

class _BedBookingScreenState extends State<BedBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  OrganizationModel? _hospital;
  String? _selectedBedType;
  Uint8List? _prescriptionImage;
  String _prescriptionContentType = 'image/jpeg';
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

    final org = await context.read<OrganizationProvider>().getOrganization(widget.organizationId);
    await context.read<BedProvider>().fetchBedsForOrg(widget.organizationId);

    if (mounted) {
      setState(() {
        _hospital = org;
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a bed type')));
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }

    final profileOk = await ProfileCompletionDialog.showIfNeeded(context);
    if (!profileOk) return;

    setState(() => _isSubmitting = true);

    try {
      final bookingProvider = context.read<BookingProvider>();
      final bedProvider = context.read<BedProvider>();
      final beds = bedProvider.getBedsForHospital(widget.organizationId);
      final selectedBed = beds.firstWhere((b) => b.type == _selectedBedType);
      final bookingId = bookingProvider.generateBookingId();

      final booking = BookingRequestModel(
        id: bookingId,
        type: 'bed',
        organizationId: widget.organizationId,
        organizationName: _hospital?.name,
        userId: auth.user!.uid,
        patientName: _nameController.text.trim(),
        contactNumber: _phoneController.text.trim(),
        createdAt: DateTime.now(),
        bedId: selectedBed.id,
        bedType: _selectedBedType,
        prescriptionDocumentId: bookingId,
        estimatedPrice: selectedBed.pricePerDay,
      );

      await bookingProvider.createBookingWithPrescription(
        booking,
        _prescriptionImage!,
        contentType: _prescriptionContentType,
      );
      if (mounted) context.go('/booking/${booking.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bedProvider = context.watch<BedProvider>();
    final beds = bedProvider.getBedsForHospital(widget.organizationId);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_hospital == null) return const Center(child: Text('Hospital not found'));

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
                    Text('Book a Bed', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_hospital!.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(_hospital!.address, style: TextStyle(color: Colors.grey.shade500)),
                    const Divider(height: 32),
                    DropdownButtonFormField<String>(
                      value: _selectedBedType,
                      decoration: const InputDecoration(labelText: 'Bed Type', prefixIcon: Icon(Icons.bed)),
                      items: beds.map((b) {
                        return DropdownMenuItem(
                          value: b.type,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(b.type),
                              PriceWidget(price: b.pricePerDay, label: 'day'),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedBedType = v),
                      validator: (v) => v == null ? 'Select a bed type' : null,
                    ),
                    if (_selectedBedType != null) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final bed = beds.firstWhere((b) => b.type == _selectedBedType);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${bed.availableBeds} beds available', style: TextStyle(color: Colors.blue.shade700)),
                              EstimatedPriceWidget(price: bed.pricePerDay, label: 'day'),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Patient Name', prefixIcon: Icon(Icons.person)),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Contact Number', prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      validator: Validators.validatePhone,
                    ),
                    const SizedBox(height: 16),
                    PrescriptionUploadField(
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
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Booking Request'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The hospital will review your request and call you to verify before confirming.',
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
