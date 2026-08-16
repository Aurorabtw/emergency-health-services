import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/prescription_service.dart';

/// A required prescription image picker that integrates with [Form] validation.
///
/// Because it extends [FormField], calling `formKey.currentState!.validate()`
/// will flag a missing prescription just like any other required field.
/// The picked bytes and file name are reported back via [onChanged].
class PrescriptionUploadField extends FormField<Uint8List> {
  PrescriptionUploadField({
    super.key,
    required this.onChanged,
  }) : super(
          validator: (value) {
            if (value == null) return 'Prescription is required';
            if (value.lengthInBytes >
                PrescriptionService.maxPrescriptionBytes) {
              return 'Prescription must be 700 KB or smaller';
            }
            return null;
          },
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
  final void Function(
    Uint8List bytes,
    String fileName,
    String contentType,
  ) onChanged;

  @override
  FormFieldState<Uint8List> createState() => _PrescriptionUploadFieldState();
}

class _PrescriptionUploadFieldState extends FormFieldState<Uint8List> {
  String? _fileName;

  PrescriptionUploadField get _field => widget as PrescriptionUploadField;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final contentType = file.mimeType ?? _contentTypeFromName(file.name);
    setState(() => _fileName = file.name);
    didChange(bytes);
    _field.onChanged(bytes, file.name, contentType);
  }

  String _contentTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
