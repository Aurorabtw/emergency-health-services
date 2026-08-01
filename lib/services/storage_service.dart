import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    String? contentType,
  }) async {
    final ref = _storage.ref().child(path);
    final metadata = contentType != null ? SettableMetadata(contentType: contentType) : null;
    await ref.putData(data, metadata);
    return ref.getDownloadURL();
  }

  Future<void> deleteFile(String path) {
    return _storage.ref().child(path).delete();
  }
}
