import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../utils/validators.dart';

class ProfileCompletionDialog extends StatefulWidget {
  const ProfileCompletionDialog({super.key});

  static Future<bool> showIfNeeded(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.isProfileComplete) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProfileCompletionDialog(),
    );
    return result ?? false;
  }

  @override
  State<ProfileCompletionDialog> createState() => _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends State<ProfileCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user?.name != null) _nameController.text = user!.name!;
    if (user?.phone != null) _phoneController.text = user!.phone!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().updateProfile(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete Your Profile'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide your name and phone number to make a booking. '
              'The hospital/operator will use this number to contact you.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: Validators.validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                hintText: '+880...',
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save & Continue'),
        ),
      ],
    );
  }
}
