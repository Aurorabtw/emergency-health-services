import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionService {
  static const int maxPrescriptionBytes = 700 * 1024;
  static const Set<String> allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final FirebaseFirestore _db;

  PrescriptionService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static Map<String, dynamic> documentData({
    required String bookingId,
    required String userId,
    required String organizationId,
    required String bookingType,
    required Uint8List data,
    required String contentType,
  }) {
    if (data.isEmpty || data.lengthInBytes > maxPrescriptionBytes) {
      throw ArgumentError('Prescription images must be 700 KB or smaller.');
    }
    if (!allowedContentTypes.contains(contentType)) {
      throw ArgumentError('Unsupported prescription image type.');
    }
    if (!_matchesContentType(data, contentType)) {
      throw ArgumentError('The selected file does not match its image type.');
    }
    return {
      'booking_id': bookingId,
      'user_id': userId,
      'organization_id': organizationId,
      'booking_type': bookingType,
      'content_type': contentType,
      'image_bytes': Blob(data),
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  Future<Uint8List> download(String documentId) async {
    final snapshot = await _db
        .collection('prescription_documents')
        .doc(documentId)
        .get();
    final data = snapshot.data();
    final image = data?['image_bytes'];
    if (image is! Blob) throw StateError('Prescription image is unavailable.');
    return image.bytes;
  }

  static bool _matchesContentType(Uint8List data, String contentType) {
    if (contentType == 'image/jpeg') {
      return data.lengthInBytes >= 3 &&
          data[0] == 0xff &&
          data[1] == 0xd8 &&
          data[2] == 0xff;
    }
    if (contentType == 'image/png') {
      const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
      if (data.lengthInBytes < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (data[index] != signature[index]) return false;
      }
      return true;
    }
    if (contentType == 'image/webp') {
      return data.lengthInBytes >= 12 &&
          String.fromCharCodes(data.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(data.sublist(8, 12)) == 'WEBP';
    }
    return false;
  }
}
