import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // ── Configure these in your Cloudinary dashboard ──
  // Dashboard → Settings → Upload → Upload presets → Add unsigned preset
  static const String cloudName = 'iy2jexgs';
  static const String uploadPreset = 'hospital_services';

  /// Uploads an image to Cloudinary using unsigned upload.
  /// Returns the secure URL of the uploaded image.
  Future<String> uploadImage(
    Uint8List data, {
    String? fileName,
    String folder = 'prescriptions',
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final base64Image = base64Encode(data);
    final dataUri = 'data:image/jpeg;base64,$base64Image';

    final response = await http.post(
      uri,
      body: {'file': dataUri, 'upload_preset': uploadPreset, 'folder': folder},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['secure_url'] as String;
    } else {
      debugPrint(
        'Cloudinary upload error: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to upload image');
    }
  }

  /// Deletes an image from Cloudinary by its public ID.
  /// Note: Deletion requires signed requests (API key + secret),
  /// which should not be done from the client. For production,
  /// handle deletion via a backend or Cloud Function.
  Future<void> deleteImage(String publicId) async {
    debugPrint(
      'Cloudinary deletion requires server-side auth — skipping for $publicId',
    );
  }
}
