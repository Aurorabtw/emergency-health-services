import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseFirestore get db => _db;

  Future<DocumentSnapshot> getDocument(String path) {
    return _db.doc(path).get();
  }

  Future<void> setDocument(String path, Map<String, dynamic> data) {
    return _db.doc(path).set(data);
  }

  Future<void> updateDocument(String path, Map<String, dynamic> data) {
    return _db.doc(path).update(data);
  }

  Future<void> deleteDocument(String path) {
    return _db.doc(path).delete();
  }

  Future<QuerySnapshot> getCollection(
    String path, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query query = _db.collection(path);

    if (filters != null) {
      for (final filter in filters) {
        query = query.where(filter.field, isEqualTo: filter.isEqualTo, isGreaterThan: filter.isGreaterThan, isLessThan: filter.isLessThan);
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.get();
  }

  Future<QueryPage> getCollectionPage(
    String path, {
    List<QueryFilter>? filters,
    required String orderBy,
    bool descending = false,
    int pageSize = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _db.collection(path);
    if (filters != null) {
      for (final filter in filters) {
        query = query.where(
          filter.field,
          isEqualTo: filter.isEqualTo,
          isGreaterThan: filter.isGreaterThan,
          isLessThan: filter.isLessThan,
        );
      }
    }
    query = query.orderBy(orderBy, descending: descending);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snapshot = await query.limit(pageSize + 1).get();
    final hasMore = snapshot.docs.length > pageSize;
    final docs = snapshot.docs.take(pageSize).toList();
    return QueryPage(
      docs: docs,
      lastDocument: docs.isEmpty ? startAfter : docs.last,
      hasMore: hasMore,
    );
  }

  /// Fetches every document in a subcollection across ALL parents in one
  /// request (e.g. all `beds` under every organization). The caller derives
  /// each doc's parent via `doc.reference.parent.parent`.
  Future<QuerySnapshot> getCollectionGroup(String collectionId) {
    return _db.collectionGroup(collectionId).get();
  }

  Stream<QuerySnapshot> streamCollection(
    String path, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query query = _db.collection(path);

    if (filters != null) {
      for (final filter in filters) {
        query = query.where(filter.field, isEqualTo: filter.isEqualTo, isGreaterThan: filter.isGreaterThan, isLessThan: filter.isLessThan);
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    if (limit != null) query = query.limit(limit);

    return query.snapshots();
  }

  Stream<DocumentSnapshot> streamDocument(String path) {
    return _db.doc(path).snapshots();
  }

  Future<T> runTransaction<T>(Future<T> Function(Transaction) handler) {
    return _db.runTransaction(handler);
  }

  CollectionReference collection(String path) => _db.collection(path);

  DocumentReference doc(String path) => _db.doc(path);

  String generateId(String collectionPath) {
    return _db.collection(collectionPath).doc().id;
  }
}

class QueryFilter {
  final String field;
  final dynamic isEqualTo;
  final dynamic isGreaterThan;
  final dynamic isLessThan;

  QueryFilter({
    required this.field,
    this.isEqualTo,
    this.isGreaterThan,
    this.isLessThan,
  });
}

class QueryPage {
  final List<QueryDocumentSnapshot> docs;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const QueryPage({
    required this.docs,
    required this.lastDocument,
    required this.hasMore,
  });
}
