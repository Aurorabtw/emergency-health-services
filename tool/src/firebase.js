'use strict';

const {applicationDefault, deleteApp, initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {FieldPath, GeoPoint, Timestamp, getFirestore} = require('firebase-admin/firestore');

function initializeFirebase(projectId) {
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Firebase emulator environment variables are not supported by this production tool.');
  }
  if (typeof projectId !== 'string' || projectId.length === 0) {
    throw new Error('--project-id is required for every command that contacts Firebase.');
  }
  const app = initializeApp({credential: applicationDefault(), projectId});
  return {
    app,
    auth: getAuth(app),
    close: () => deleteApp(app),
    db: getFirestore(app),
    projectId,
  };
}

async function readQueryInPages(query, pageSize = 500) {
  const documents = [];
  let cursor = null;
  for (;;) {
    let pageQuery = query.orderBy(FieldPath.documentId()).limit(pageSize);
    if (cursor) pageQuery = pageQuery.startAfter(cursor);
    const page = await pageQuery.get();
    documents.push(...page.docs);
    if (page.size < pageSize) return documents;
    cursor = page.docs[page.docs.length - 1];
  }
}

function decodeFirestoreValue(value, db) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string' ||
      typeof value === 'number') return value;
  if (Array.isArray(value)) return value.map((child) => decodeFirestoreValue(child, db));
  if (!value || typeof value !== 'object') throw new Error('Unsupported encoded Firestore value.');
  if (value.__firestoreType === 'timestamp') {
    return new Timestamp(Number(value.seconds), value.nanoseconds);
  }
  if (value.__firestoreType === 'date') return new Date(value.iso);
  if (value.__firestoreType === 'bytes') return Buffer.from(value.base64, 'base64');
  if (value.__firestoreType === 'geopoint') return new GeoPoint(value.latitude, value.longitude);
  if (value.__firestoreType === 'reference') return db.doc(value.path);
  if (value.__firestoreType) throw new Error('Unknown encoded Firestore value.');
  const result = {};
  for (const [key, child] of Object.entries(value)) result[key] = decodeFirestoreValue(child, db);
  return result;
}

module.exports = {decodeFirestoreValue, initializeFirebase, readQueryInPages};
