'use strict';

const {contentHash, encodeFirestoreValue} = require('./canonical');
const {decodeFirestoreValue, readQueryInPages} = require('./firebase');
const {
  INVENTORIES,
  analyzeInventory,
  createManifest,
  resultDataForAction,
  validateManifest,
} = require('./planner');

const REFERENCE_BATCH_SIZE = 450;

function compareText(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

function sameTimestamp(left, right) {
  return Boolean(left && right && left.seconds === right.seconds && left.nanoseconds === right.nanoseconds);
}

async function loadAuthUserIds(auth) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users.map((user) => ({uid: user.uid, disabled: user.disabled})));
    pageToken = page.pageToken;
  } while (pageToken);
  users.sort((a, b) => compareText(a.uid, b.uid));
  return users;
}

async function auditProfiles({auth, db, projectId}) {
  const [authUsers, profileDocs] = await Promise.all([
    loadAuthUserIds(auth),
    readQueryInPages(db.collection('users').select()),
  ]);
  const authById = new Map(authUsers.map((user) => [user.uid, user]));
  const profileIds = new Set(profileDocs.map((doc) => doc.id));
  const missingProfiles = authUsers
    .filter((user) => !profileIds.has(user.uid))
    .map((user) => ({uid: user.uid, authDisabled: user.disabled}));
  const profilesWithoutAuth = profileDocs
    .filter((doc) => !authById.has(doc.id))
    .map((doc) => ({uid: doc.id}));
  return {
    audit: 'auth_profiles',
    projectId,
    counts: {
      authUsers: authUsers.length,
      firestoreProfiles: profileDocs.length,
      missingProfiles: missingProfiles.length,
      profilesWithoutAuth: profilesWithoutAuth.length,
    },
    missingProfiles,
    profilesWithoutAuth,
  };
}

async function auditRevocations({db, projectId}) {
  const [profiles, ledgers] = await Promise.all([
    readQueryInPages(db.collection('users').select(
      'access_revoked', 'access_revoked_at', 'access_revoked_by')),
    readQueryInPages(db.collection('access_revocations').select(
      'user_id', 'revoked_at', 'revoked_by')),
  ]);
  const profileMap = new Map(profiles.map((doc) => [doc.id, doc.data()]));
  const ledgerMap = new Map(ledgers.map((doc) => [doc.id, doc.data()]));
  const userIds = [...new Set([...profileMap.keys(), ...ledgerMap.keys()])].sort(compareText);
  const issues = [];
  for (const uid of userIds) {
    const profile = profileMap.get(uid);
    const ledger = ledgerMap.get(uid);
    if (ledger && !profile) {
      issues.push({code: 'ledger_without_profile', uid});
      continue;
    }
    if (!profile) continue;
    if (profile.access_revoked === true && !ledger) {
      issues.push({code: 'revoked_profile_without_ledger', uid});
    }
    if (profile.access_revoked !== true && ledger) {
      issues.push({code: 'ledger_for_active_profile', uid});
    }
    if (profile.access_revoked === true &&
        (!profile.access_revoked_at || typeof profile.access_revoked_by !== 'string')) {
      issues.push({code: 'revoked_profile_metadata_incomplete', uid});
    }
    if (ledger) {
      if (ledger.user_id !== uid) issues.push({code: 'ledger_user_id_mismatch', uid});
      if (!ledger.revoked_at || typeof ledger.revoked_by !== 'string') {
        issues.push({code: 'ledger_metadata_incomplete', uid});
      }
      if (profile.access_revoked === true && profile.access_revoked_by && ledger.revoked_by &&
          profile.access_revoked_by !== ledger.revoked_by) {
        issues.push({code: 'revocation_actor_mismatch', uid});
      }
      if (profile.access_revoked === true && profile.access_revoked_at && ledger.revoked_at &&
          !sameTimestamp(profile.access_revoked_at, ledger.revoked_at)) {
        issues.push({code: 'revocation_timestamp_mismatch', uid});
      }
    }
  }
  return {
    audit: 'access_revocations',
    projectId,
    counts: {profiles: profiles.length, ledgerEntries: ledgers.length, issues: issues.length},
    issues,
  };
}

async function loadInventoryDocuments(db) {
  const snapshots = await Promise.all(Object.keys(INVENTORIES).map(async (collection) => ({
    collection,
    docs: await readQueryInPages(db.collectionGroup(collection)),
  })));
  const documents = [];
  const placementIssues = [];
  for (const group of snapshots) {
    for (const doc of group.docs) {
      const segments = doc.ref.path.split('/');
      if (segments.length !== 4 || segments[0] !== 'organizations' || segments[2] !== group.collection) {
        placementIssues.push({code: 'unexpected_inventory_path', documentPath: doc.ref.path});
        continue;
      }
      documents.push({
        id: doc.id,
        organizationId: segments[1],
        collection: group.collection,
        data: encodeFirestoreValue(doc.data()),
      });
    }
  }
  documents.sort((a, b) => compareText(
    `${a.organizationId}\u0000${a.collection}\u0000${a.id}`,
    `${b.organizationId}\u0000${b.collection}\u0000${b.id}`,
  ));
  placementIssues.sort((a, b) => compareText(a.documentPath, b.documentPath));
  return {documents, placementIssues};
}

async function loadBookingReferences(db) {
  const docs = await readQueryInPages(db.collection('booking_requests').select(
    'organization_id', 'type', 'bed_id', 'blood_stock_id'));
  return docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      organizationId: data.organization_id,
      type: data.type,
      bed_id: data.bed_id,
      blood_stock_id: data.blood_stock_id,
    };
  }).sort((a, b) => compareText(a.id, b.id));
}

async function auditInventory({db, projectId}) {
  const {documents, placementIssues} = await loadInventoryDocuments(db);
  const analysis = analyzeInventory(documents);
  const issues = placementIssues.concat(analysis.issues);
  return {
    audit: 'inventory',
    projectId,
    counts: {documents: documents.length, issues: issues.length, migrationCandidates: analysis.candidates.length},
    issues,
  };
}

async function generateManifest({db, projectId}) {
  const [{documents, placementIssues}, bookings] = await Promise.all([
    loadInventoryDocuments(db), loadBookingReferences(db),
  ]);
  const manifest = createManifest({projectId, documents, bookings});
  manifest.blockingIssues.push(...placementIssues);
  manifest.blockingIssues.sort((a, b) => compareText(
    `${a.organizationId || ''}\u0000${a.collection || ''}\u0000${a.documentPath || ''}\u0000${a.code}`,
    `${b.organizationId || ''}\u0000${b.collection || ''}\u0000${b.documentPath || ''}\u0000${b.code}`,
  ));
  return manifest;
}

async function queryOrganizationBookings(db, action) {
  const config = INVENTORIES[action.collection];
  const docs = await readQueryInPages(db.collection('booking_requests')
    .where('organization_id', '==', action.organizationId)
    .select('type', config.referenceField));
  return docs.filter((doc) => doc.get('type') === config.bookingType);
}

function encodedSnapshotHash(snapshot) {
  return contentHash(encodeFirestoreValue(snapshot.data()));
}

function sameDocumentIds(documents, expectedIds) {
  const actualIds = documents.map((doc) => doc.id).sort(compareText);
  const sortedExpected = [...expectedIds].sort(compareText);
  return actualIds.length === sortedExpected.length &&
    actualIds.every((id, index) => id === sortedExpected[index]);
}

async function actionAlreadyApplied(db, action) {
  const target = await db.doc(`organizations/${action.organizationId}/${action.collection}/${action.targetId}`).get();
  if (!target.exists || encodedSnapshotHash(target) !== contentHash(resultDataForAction(action))) return false;
  const oldIds = action.documents.map((doc) => doc.id).filter((id) => id !== action.targetId);
  const oldSnapshots = await Promise.all(oldIds.map((id) =>
    db.doc(`organizations/${action.organizationId}/${action.collection}/${id}`).get()));
  if (oldSnapshots.some((snapshot) => snapshot.exists)) return false;
  const config = INVENTORIES[action.collection];
  const bookings = await queryOrganizationBookings(db, action);
  return !bookings.some((doc) => oldIds.includes(doc.get(config.referenceField)));
}

async function preflightAction(db, action) {
  if (action.documents.length + 1 > 500) {
    throw new Error(`${action.actionId}: too many source documents for an atomic finalization.`);
  }
  const expectedById = new Map(action.documents.map((doc) => [doc.id, doc]));
  const snapshots = await Promise.all(action.documents.map((doc) =>
    db.doc(`organizations/${action.organizationId}/${action.collection}/${doc.id}`).get()));
  for (const snapshot of snapshots) {
    const expected = expectedById.get(snapshot.id);
    if (!snapshot.exists || encodedSnapshotHash(snapshot) !== expected.dataHash) {
      throw new Error(`${action.actionId}: inventory changed since manifest generation.`);
    }
  }
  if (!expectedById.has(action.targetId)) {
    const target = await db.doc(
      `organizations/${action.organizationId}/${action.collection}/${action.targetId}`).get();
    const survivor = expectedById.get(action.decision.survivorSourceId);
    if (target.exists && encodedSnapshotHash(target) !== survivor.dataHash) {
      throw new Error(`${action.actionId}: canonical target appeared or changed; regenerate the manifest.`);
    }
  }

  const config = INVENTORIES[action.collection];
  const relevantIds = new Set(action.documents.map((doc) => doc.id).concat(action.targetId));
  const bookings = (await queryOrganizationBookings(db, action))
    .filter((doc) => relevantIds.has(doc.get(config.referenceField)));
  if (!sameDocumentIds(bookings, action.referenceDocumentIds)) {
    throw new Error(`${action.actionId}: booking references changed since manifest generation.`);
  }
  return bookings;
}

async function ensureTargetExists(db, action) {
  if (action.documents.some((doc) => doc.id === action.targetId)) return;
  const sourcePath = `organizations/${action.organizationId}/${action.collection}/${action.decision.survivorSourceId}`;
  const targetPath = `organizations/${action.organizationId}/${action.collection}/${action.targetId}`;
  const expected = action.documents.find((doc) => doc.id === action.decision.survivorSourceId);
  await db.runTransaction(async (transaction) => {
    const [source, target] = await Promise.all([
      transaction.get(db.doc(sourcePath)), transaction.get(db.doc(targetPath)),
    ]);
    if (!source.exists || encodedSnapshotHash(source) !== expected.dataHash) {
      throw new Error(`${action.actionId}: survivor changed before target creation.`);
    }
    if (target.exists) {
      if (encodedSnapshotHash(target) !== expected.dataHash) {
        throw new Error(`${action.actionId}: canonical target conflicts with the manifest.`);
      }
      return;
    }
    transaction.create(db.doc(targetPath), decodeFirestoreValue(expected.data, db));
  });
}

async function moveReferencesInBatches(db, action, bookings, onProgress) {
  const config = INVENTORIES[action.collection];
  const toMove = bookings.filter((doc) => doc.get(config.referenceField) !== action.targetId);
  for (let start = 0; start < toMove.length; start += REFERENCE_BATCH_SIZE) {
    const group = toMove.slice(start, start + REFERENCE_BATCH_SIZE);
    const batch = db.batch();
    for (const snapshot of group) {
      batch.update(snapshot.ref, {[config.referenceField]: action.targetId}, {lastUpdateTime: snapshot.updateTime});
    }
    await batch.commit();
    onProgress({actionId: action.actionId, phase: 'references', writes: group.length});
  }
}

async function finalizeAction(db, action) {
  const config = INVENTORIES[action.collection];
  const sourceIds = new Set(action.documents.map((doc) => doc.id));
  const expectedById = new Map(action.documents.map((doc) => [doc.id, doc]));
  const targetRef = db.doc(`organizations/${action.organizationId}/${action.collection}/${action.targetId}`);
  const resultData = decodeFirestoreValue(resultDataForAction(action), db);
  await db.runTransaction(async (transaction) => {
    const sourceSnapshots = await transaction.getAll(...action.documents.map((doc) => db.doc(
      `organizations/${action.organizationId}/${action.collection}/${doc.id}`)));
    for (const snapshot of sourceSnapshots) {
      const expected = expectedById.get(snapshot.id);
      if (!snapshot.exists || encodedSnapshotHash(snapshot) !== expected.dataHash) {
        throw new Error(`${action.actionId}: inventory changed during migration.`);
      }
    }
    let targetSnapshot = sourceSnapshots.find((snapshot) => snapshot.id === action.targetId);
    if (!targetSnapshot) targetSnapshot = await transaction.get(targetRef);
    if (!targetSnapshot.exists) throw new Error(`${action.actionId}: canonical target is missing.`);
    if (!expectedById.has(action.targetId)) {
      const survivor = expectedById.get(action.decision.survivorSourceId);
      if (encodedSnapshotHash(targetSnapshot) !== survivor.dataHash) {
        throw new Error(`${action.actionId}: staged canonical target changed during migration.`);
      }
    }

    const bookingQuery = db.collection('booking_requests')
      .where('organization_id', '==', action.organizationId)
      .select('type', config.referenceField);
    const bookingSnapshot = await transaction.get(bookingQuery);
    const relevantIds = new Set([...sourceIds, action.targetId]);
    const relevantBookings = bookingSnapshot.docs.filter((doc) =>
      doc.get('type') === config.bookingType && relevantIds.has(doc.get(config.referenceField)));
    if (!sameDocumentIds(relevantBookings, action.referenceDocumentIds)) {
      throw new Error(`${action.actionId}: booking references changed during migration.`);
    }
    const remaining = relevantBookings.filter((doc) =>
      sourceIds.has(doc.get(config.referenceField)) && doc.get(config.referenceField) !== action.targetId);
    const finalWrites = remaining.length + action.documents.filter((doc) => doc.id !== action.targetId).length + 1;
    if (finalWrites > 500) {
      throw new Error(`${action.actionId}: too many late references to finalize atomically; rerun apply.`);
    }
    for (const booking of remaining) {
      transaction.update(booking.ref, {[config.referenceField]: action.targetId});
    }
    transaction.set(targetRef, resultData);
    for (const source of action.documents) {
      if (source.id !== action.targetId) transaction.delete(
        db.doc(`organizations/${action.organizationId}/${action.collection}/${source.id}`));
    }
  });
}

async function verifyAction(db, action) {
  const result = {actionId: action.actionId, ok: true, failures: []};
  const target = await db.doc(`organizations/${action.organizationId}/${action.collection}/${action.targetId}`).get();
  if (!target.exists) result.failures.push('canonical_target_missing');
  else if (encodedSnapshotHash(target) !== contentHash(resultDataForAction(action))) {
    result.failures.push('canonical_target_data_mismatch');
  }
  const oldIds = action.documents.map((doc) => doc.id).filter((id) => id !== action.targetId);
  const oldDocs = await Promise.all(oldIds.map((id) => db.doc(
    `organizations/${action.organizationId}/${action.collection}/${id}`).get()));
  if (oldDocs.some((doc) => doc.exists)) result.failures.push('source_documents_remain');
  const config = INVENTORIES[action.collection];
  const bookings = await queryOrganizationBookings(db, action);
  if (bookings.some((doc) => oldIds.includes(doc.get(config.referenceField)))) {
    result.failures.push('old_booking_references_remain');
  }
  const referencesToTarget = bookings.filter((doc) => doc.get(config.referenceField) === action.targetId);
  if (!sameDocumentIds(referencesToTarget, action.referenceDocumentIds)) {
    result.failures.push('reviewed_booking_reference_set_mismatch');
  }
  result.ok = result.failures.length === 0;
  return result;
}

async function applyManifest({db, projectId}, manifest, onProgress = () => {}) {
  validateManifest(manifest);
  if (manifest.projectId !== projectId) throw new Error('Manifest projectId does not match --project-id.');
  const results = [];
  for (const action of manifest.actions) {
    if (await actionAlreadyApplied(db, action)) {
      onProgress({actionId: action.actionId, phase: 'already_applied', writes: 0});
      results.push(await verifyAction(db, action));
      continue;
    }
    const bookings = await preflightAction(db, action);
    await ensureTargetExists(db, action);
    await moveReferencesInBatches(db, action, bookings, onProgress);
    await finalizeAction(db, action);
    onProgress({actionId: action.actionId, phase: 'finalized', writes: 1});
    results.push(await verifyAction(db, action));
  }
  return {verification: results, ok: results.every((result) => result.ok)};
}

async function verifyManifest({db, projectId}, manifest) {
  validateManifest(manifest);
  if (manifest.projectId !== projectId) throw new Error('Manifest projectId does not match --project-id.');
  const verification = [];
  for (const action of manifest.actions) verification.push(await verifyAction(db, action));
  return {verification, ok: verification.every((result) => result.ok)};
}

module.exports = {
  applyManifest,
  auditInventory,
  auditProfiles,
  auditRevocations,
  generateManifest,
  verifyManifest,
};
