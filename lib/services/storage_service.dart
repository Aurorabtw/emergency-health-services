import 'dart:typed_data';

import 'cloudinary_service.dart';

/// Storage service that delegates to Cloudinary.
/// Drop-in replacement for the old Firebase Storage-based service.
class StorageService {
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    String? contentType,
  }) {
    final folder = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : 'uploads';
    return _cloudinary.uploadImage(data, folder: folder);
  }

  Future<void> deleteFile(String path) {
    return _cloudinary.deleteImage(path);
  }
}
