'use strict';

const crypto = require('node:crypto');

function canonicalize(value) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError('Non-finite numbers are not supported.');
    return Object.is(value, -0) ? 0 : value;
  }
  if (Array.isArray(value)) return value.map(canonicalize);
  if (typeof value === 'object') {
    const result = {};
    for (const key of Object.keys(value).sort()) {
      if (value[key] === undefined) throw new TypeError(`Undefined value at ${key}.`);
      result[key] = canonicalize(value[key]);
    }
    return result;
  }
  throw new TypeError(`Unsupported manifest value type: ${typeof value}.`);
}

function stableStringify(value, spacing = 0) {
  return JSON.stringify(canonicalize(value), null, spacing);
}

function contentHash(value) {
  return crypto.createHash('sha256').update(stableStringify(value)).digest('hex');
}

function encodeFirestoreValue(value) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string' ||
      typeof value === 'number') {
    return value;
  }
  if (Array.isArray(value)) return value.map(encodeFirestoreValue);
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    return {__firestoreType: 'bytes', base64: Buffer.from(value).toString('base64')};
  }
  if (value instanceof Date) {
    return {__firestoreType: 'date', iso: value.toISOString()};
  }
  if (value && Number.isInteger(value.seconds) && Number.isInteger(value.nanoseconds) &&
      typeof value.toDate === 'function') {
    return {
      __firestoreType: 'timestamp',
      seconds: String(value.seconds),
      nanoseconds: value.nanoseconds,
    };
  }
  if (value && typeof value.latitude === 'number' && typeof value.longitude === 'number') {
    return {__firestoreType: 'geopoint', latitude: value.latitude, longitude: value.longitude};
  }
  if (value && typeof value.path === 'string' && value.firestore) {
    return {__firestoreType: 'reference', path: value.path};
  }
  if (value && typeof value === 'object') {
    const result = {};
    for (const [key, child] of Object.entries(value)) result[key] = encodeFirestoreValue(child);
    return result;
  }
  throw new TypeError('Unsupported Firestore value in inventory document.');
}

module.exports = {canonicalize, contentHash, encodeFirestoreValue, stableStringify};
