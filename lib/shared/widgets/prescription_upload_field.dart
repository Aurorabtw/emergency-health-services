import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A required prescription image picker that integrates with [Form] validation.
///
/// Because it extends [FormField], calling `formKey.currentState!.validate()`
/// will flag a missing prescription just like any other required field.
/// The picked bytes and file name are reported back via [onChanged] so the
/// parent can upload them on submit.
class PrescriptionUploadField extends FormField<Uint8List> {
  PrescriptionUploadField({
    super.key,
    required this.onChanged,
  }) : super(
          validator: (value) =>
              value == null ? 'Prescription is required' : null,
          builder: (state) {
            final field = state as _PrescriptionUploadFieldState;
            final theme = Theme.of(state.context);
            final hasFile = state.value != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: field._pick,
                  icon: Icon(
                    hasFile ? Icons.check_circle : Icons.upload_file,
                    color: hasFile ? Colors.green : null,
                  ),
                  label: Text(
                    field._fileName ?? 'Upload Prescription (required)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );

  /// Called whenever a new image is picked, with the raw bytes and file name.
  final void Function(Uint8List bytes, String fileName) onChanged;

  @override
  FormFieldState<Uint8List> createState() => _PrescriptionUploadFieldState();
}

class _PrescriptionUploadFieldState extends FormFieldState<Uint8List> {
  String? _fileName;

  PrescriptionUploadField get _field => widget as PrescriptionUploadField;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _fileName = file.name);
    didChange(bytes);
    _field.onChanged(bytes, file.name);
  }
}
