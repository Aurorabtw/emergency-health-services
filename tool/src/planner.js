'use strict';

const {contentHash} = require('./canonical');

const INVENTORIES = Object.freeze({
  beds: {
    bookingType: 'bed',
    referenceField: 'bed_id',
    valueField: 'type',
    canonicalIds: {General: 'general', ICU: 'icu', NICU: 'nicu'},
    counters: ['total_beds', 'held_beds', 'admitted_beds'],
    occupied: ['held_beds', 'admitted_beds'],
    totalMinimum: 1,
  },
  blood_stock: {
    bookingType: 'blood',
    referenceField: 'blood_stock_id',
    valueField: 'blood_type',
    canonicalIds: {
      'A+': 'a_positive', 'A-': 'a_negative',
      'B+': 'b_positive', 'B-': 'b_negative',
      'AB+': 'ab_positive', 'AB-': 'ab_negative',
      'O+': 'o_positive', 'O-': 'o_negative',
    },
    counters: ['total_units', 'held_units', 'issued_units'],
    occupied: ['held_units', 'issued_units'],
    totalMinimum: 0,
  },
});

function compareText(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

function analyzeInventory(documents) {
  const issues = [];
  const eligible = [];
  const occupiedByPath = new Map(documents.map((doc) => [`${doc.organizationId}/${doc.collection}/${doc.id}`, doc]));

  for (const doc of documents) {
    const config = INVENTORIES[doc.collection];
    const value = doc.data[config.valueField];
    if (typeof value !== 'string' || !Object.hasOwn(config.canonicalIds, value)) {
      issues.push({
        code: 'invalid_inventory_value',
        organizationId: doc.organizationId,
        collection: doc.collection,
        documentIds: [doc.id],
      });
      continue;
    }
    const numericFieldsValid = config.counters.every(
      (field) => Number.isInteger(doc.data[field]) && doc.data[field] >= 0,
    );
    const occupied = config.occupied.reduce((sum, field) => sum + (doc.data[field] || 0), 0);
    if (!numericFieldsValid || doc.data[config.counters[0]] < config.totalMinimum ||
        doc.data[config.counters[0]] < occupied) {
      issues.push({
        code: 'invalid_inventory_counters',
        organizationId: doc.organizationId,
        collection: doc.collection,
        documentIds: [doc.id],
      });
      continue;
    }
    eligible.push({...doc, canonicalValue: value, canonicalId: config.canonicalIds[value]});
  }

  const groups = new Map();
  for (const doc of eligible) {
    const key = `${doc.organizationId}\u0000${doc.collection}\u0000${doc.canonicalValue}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(doc);
  }

  const candidates = [];
  for (const docs of groups.values()) {
    docs.sort((a, b) => compareText(a.id, b.id));
    const first = docs[0];
    const needsMigration = docs.length > 1 || first.id !== first.canonicalId;
    if (!needsMigration) continue;

    const targetPath = `${first.organizationId}/${first.collection}/${first.canonicalId}`;
    const collision = occupiedByPath.get(targetPath);
    if (collision && !docs.some((doc) => doc.id === collision.id)) {
      issues.push({
        code: 'canonical_id_collision',
        organizationId: first.organizationId,
        collection: first.collection,
        canonicalValue: first.canonicalValue,
        documentIds: docs.map((doc) => doc.id).concat(collision.id).sort(compareText),
      });
      continue;
    }

    issues.push({
      code: docs.length > 1 ? 'duplicate_inventory' : 'noncanonical_inventory_id',
      organizationId: first.organizationId,
      collection: first.collection,
      canonicalValue: first.canonicalValue,
      canonicalId: first.canonicalId,
      documentIds: docs.map((doc) => doc.id),
    });
    candidates.push({
      organizationId: first.organizationId,
      collection: first.collection,
      canonicalValue: first.canonicalValue,
      targetId: first.canonicalId,
      documents: docs,
    });
  }

  const issueOrder = (issue) => [issue.organizationId, issue.collection, issue.canonicalValue || '', issue.code].join('\u0000');
  issues.sort((a, b) => compareText(issueOrder(a), issueOrder(b)));
  candidates.sort((a, b) => compareText(
    `${a.organizationId}\u0000${a.collection}\u0000${a.canonicalValue}`,
    `${b.organizationId}\u0000${b.collection}\u0000${b.canonicalValue}`,
  ));
  return {issues, candidates};
}

function createManifest({projectId, documents, bookings}) {
  const analysis = analyzeInventory(documents);
  const blockingIssues = analysis.issues.filter((issue) =>
    issue.code === 'invalid_inventory_value' || issue.code === 'invalid_inventory_counters' ||
    issue.code === 'canonical_id_collision');
  const actions = analysis.candidates.map((candidate) => {
    const config = INVENTORIES[candidate.collection];
    const sourceIds = new Set(candidate.documents.map((doc) => doc.id));
    const referenceDocumentIds = bookings
      .filter((booking) => booking.organizationId === candidate.organizationId &&
        booking.type === config.bookingType && sourceIds.has(booking[config.referenceField]))
      .map((booking) => booking.id)
      .sort(compareText);
    const isUnambiguousRename = candidate.documents.length === 1;
    return {
      actionId: [candidate.collection, candidate.organizationId, candidate.canonicalValue].join(':'),
      kind: 'merge_inventory',
      organizationId: candidate.organizationId,
      collection: candidate.collection,
      canonicalValue: candidate.canonicalValue,
      targetId: candidate.targetId,
      documents: candidate.documents.map((doc) => ({
        id: doc.id,
        dataHash: contentHash(doc.data),
        data: doc.data,
      })),
      referenceDocumentIds,
      decision: isUnambiguousRename ? {
        survivorSourceId: candidate.documents[0].id,
        counterStrategy: {mode: 'survivor'},
      } : {
        survivorSourceId: null,
        counterStrategy: null,
      },
    };
  });
  return {schemaVersion: 1, projectId, blockingIssues, actions};
}

function validateSafeId(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.includes('/')) {
    throw new Error(`${label} must be a non-empty Firestore document ID.`);
  }
}

function validateDecision(action) {
  if (!action || action.kind !== 'merge_inventory' || !INVENTORIES[action.collection]) {
    throw new Error('Manifest contains an unsupported action.');
  }
  validateSafeId(action.organizationId, 'organizationId');
  validateSafeId(action.targetId, 'targetId');
  const config = INVENTORIES[action.collection];
  if (config.canonicalIds[action.canonicalValue] !== action.targetId) {
    throw new Error(`${action.actionId}: targetId is not canonical.`);
  }
  if (!Array.isArray(action.documents) || action.documents.length === 0) {
    throw new Error(`${action.actionId}: no source documents.`);
  }
  const ids = action.documents.map((doc) => doc.id);
  ids.forEach((id) => validateSafeId(id, 'source id'));
  if (new Set(ids).size !== ids.length) throw new Error(`${action.actionId}: duplicate source IDs.`);
  for (const doc of action.documents) {
    if (!doc.data || contentHash(doc.data) !== doc.dataHash ||
        doc.data[config.valueField] !== action.canonicalValue) {
      throw new Error(`${action.actionId}: source data or dataHash is invalid.`);
    }
    if (config.counters.some((field) => !Number.isInteger(doc.data[field]) || doc.data[field] < 0)) {
      throw new Error(`${action.actionId}: source counters are invalid.`);
    }
    const occupied = config.occupied.reduce((sum, field) => sum + doc.data[field], 0);
    if (doc.data[config.counters[0]] < config.totalMinimum || doc.data[config.counters[0]] < occupied) {
      throw new Error(`${action.actionId}: source counters exceed or violate total inventory.`);
    }
  }
  if (!Array.isArray(action.referenceDocumentIds) ||
      new Set(action.referenceDocumentIds).size !== action.referenceDocumentIds.length) {
    throw new Error(`${action.actionId}: referenceDocumentIds are invalid.`);
  }
  action.referenceDocumentIds.forEach((id) => validateSafeId(id, 'booking reference id'));
  const decision = action.decision;
  if (!decision || !ids.includes(decision.survivorSourceId)) {
    throw new Error(`${action.actionId}: explicitly choose survivorSourceId from the source documents.`);
  }
  const strategy = decision.counterStrategy;
  if (!strategy || !['survivor', 'sum', 'explicit'].includes(strategy.mode)) {
    throw new Error(`${action.actionId}: explicitly choose counterStrategy.mode (survivor, sum, or explicit).`);
  }
  if (strategy.mode === 'explicit') {
    if (!strategy.values || config.counters.some((field) => !Number.isInteger(strategy.values[field]) ||
      strategy.values[field] < 0)) {
      throw new Error(`${action.actionId}: explicit strategy requires non-negative integer counters.`);
    }
    const occupied = config.occupied.reduce((sum, field) => sum + strategy.values[field], 0);
    if (strategy.values[config.counters[0]] < config.totalMinimum ||
        strategy.values[config.counters[0]] < occupied) {
      throw new Error(`${action.actionId}: explicit counters exceed total inventory.`);
    }
  }
  return true;
}

function resultDataForAction(action) {
  validateDecision(action);
  const config = INVENTORIES[action.collection];
  const survivor = action.documents.find((doc) => doc.id === action.decision.survivorSourceId);
  const result = structuredClone(survivor.data);
  const strategy = action.decision.counterStrategy;
  if (strategy.mode === 'sum') {
    for (const field of config.counters) {
      result[field] = action.documents.reduce((sum, doc) => sum + doc.data[field], 0);
    }
  } else if (strategy.mode === 'explicit') {
    for (const field of config.counters) result[field] = strategy.values[field];
  }
  const occupied = config.occupied.reduce((sum, field) => sum + result[field], 0);
  if (result[config.counters[0]] < config.totalMinimum || result[config.counters[0]] < occupied) {
    throw new Error(`${action.actionId}: resulting counters exceed total inventory.`);
  }
  return result;
}

function validateManifest(manifest) {
  if (!manifest || manifest.schemaVersion !== 1 || typeof manifest.projectId !== 'string' ||
      !Array.isArray(manifest.actions) || !Array.isArray(manifest.blockingIssues)) {
    throw new Error('Unsupported or malformed manifest.');
  }
  if (manifest.blockingIssues.length > 0) {
    throw new Error('Manifest has blocking inventory issues; resolve them and regenerate it.');
  }
  for (const action of manifest.actions) validateDecision(action);
  return true;
}

module.exports = {INVENTORIES, analyzeInventory, createManifest, resultDataForAction, validateDecision, validateManifest};
