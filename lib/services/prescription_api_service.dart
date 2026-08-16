import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Client for the Vercel prescription gateway.
///
/// The gateway keeps the Cloudinary API secret and Firebase Admin key server
/// side. This client only ever sends the user's Firebase ID token, uploads the
/// image bytes directly to Cloudinary using a server-issued signature, and asks
/// the gateway for short-lived signed view URLs.
class PrescriptionApiService {
  PrescriptionApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.prescriptionApiUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  static const Map<String, String> _extensionByContentType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<String> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PrescriptionApiException('You must be signed in.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const PrescriptionApiException('Could not verify your session.');
    }
    return token;
  }

  /// Signs, uploads to Cloudinary, and finalizes the prescription for [bookingId].
  /// On success the backend has written prescription_assets/{bookingId}; the
  /// caller then creates the booking referencing it.
  Future<void> upload({
    required String bookingId,
    required String organizationId,
    required String bookingType,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final token = await _idToken();

    // 1. Ask the gateway for a signed, single-use upload.
    final signResponse = await _client.post(
      Uri.parse('$_baseUrl/api/prescriptions/sign-upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'bookingId': bookingId, 'contentType': contentType}),
    );
    if (signResponse.statusCode != 200) {
      throw _errorFrom(signResponse, 'Could not start the prescription upload.');
    }
    final signBody = jsonDecode(signResponse.body) as Map<String, dynamic>;
    final upload = signBody['upload'] as Map<String, dynamic>;
    final uploadUrl = upload['url'] as String;
    final fields = (upload['fields'] as Map).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );

    // 2. Upload the bytes straight to Cloudinary (secret never touches the client).
    final extension = _extensionByContentType[contentType] ?? 'jpg';
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'prescription.$extension',
        ),
      );
    final streamed = await _client.send(request);
    final cloudinaryResponse = await http.Response.fromStream(streamed);
    if (cloudinaryResponse.statusCode < 200 ||
        cloudinaryResponse.statusCode >= 300) {
      throw PrescriptionApiException(
        'Image upload failed (${cloudinaryResponse.statusCode}).',
      );
    }

    // 3. Finalize: the gateway verifies the upload and records the metadata.
    final finalizeResponse = await _client.post(
      Uri.parse('$_baseUrl/api/prescriptions/finalize'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bookingId': bookingId,
        'organizationId': organizationId,
        'bookingType': bookingType,
      }),
    );
    if (finalizeResponse.statusCode != 200) {
      throw _errorFrom(finalizeResponse, 'Could not save the prescription.');
    }
  }

  /// Returns a short-lived signed URL to view the prescription image.
  Future<String> viewUrl(String bookingId) async {
    final token = await _idToken();
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/prescriptions/view?bookingId=$bookingId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw _errorFrom(response, 'Could not load the prescription.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['url'] as String;
  }

  /// Removes the Cloudinary asset and its metadata. Best-effort during cleanup.
  Future<void> delete(String bookingId) async {
    final token = await _idToken();
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/prescriptions/delete?bookingId=$bookingId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw _errorFrom(response, 'Could not remove the prescription.');
    }
  }

  PrescriptionApiException _errorFrom(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['error'];
      if (message is String && message.isNotEmpty) {
        return PrescriptionApiException(message);
      }
    } catch (_) {
      // Non-JSON body; fall through to the generic message.
    }
    return PrescriptionApiException(fallback);
  }
}

class PrescriptionApiException implements Exception {
  final String message;

  const PrescriptionApiException(this.message);

  @override
  String toString() => message;
}
