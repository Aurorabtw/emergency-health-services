'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {contentHash, stableStringify} = require('../src/canonical');
const {
  analyzeInventory,
  createManifest,
  resultDataForAction,
  validateDecision,
} = require('../src/planner');

function bed(id, data = {}) {
  return {
    id,
    organizationId: 'org-1',
    collection: 'beds',
    data: {
      type: 'ICU', total_beds: 4, held_beds: 1, admitted_beds: 1,
      price_per_day: 100, hold_duration_minutes: 30, ...data,
    },
  };
}

test('canonical JSON and hashes do not depend on object key order', () => {
  const left = {z: 1, a: {y: 2, x: 3}};
  const right = {a: {x: 3, y: 2}, z: 1};
  assert.equal(stableStringify(left), stableStringify(right));
  assert.equal(contentHash(left), contentHash(right));
});

test('inventory analysis finds duplicate and noncanonical groups', () => {
  const result = analyzeInventory([
    bed('icu'), bed('legacy-icu', {total_beds: 2, held_beds: 0, admitted_beds: 0}),
    {...bed('general-old'), data: {...bed('general-old').data, type: 'General'}},
  ]);
  assert.deepEqual(result.issues.map((issue) => issue.code), [
    'noncanonical_inventory_id', 'duplicate_inventory',
  ]);
  assert.equal(result.candidates.length, 2);
});

test('manifest generation is deterministic and leaves duplicate choices unresolved', () => {
  const documents = [bed('legacy-icu'), bed('icu')];
  const bookings = [{id: 'booking-b', organizationId: 'org-1', type: 'bed', bed_id: 'legacy-icu'}];
  const first = createManifest({projectId: 'project-1', documents, bookings});
  const second = createManifest({projectId: 'project-1', documents: [...documents].reverse(), bookings});
  assert.equal(stableStringify(first), stableStringify(second));
  assert.equal(first.actions[0].decision.survivorSourceId, null);
  assert.throws(() => validateDecision(first.actions[0]), /explicitly choose survivorSourceId/);
});

test('sum and explicit plans produce validated counters', () => {
  const manifest = createManifest({
    projectId: 'project-1',
    documents: [bed('icu'), bed('legacy-icu', {total_beds: 2, held_beds: 1, admitted_beds: 0})],
    bookings: [],
  });
  const action = manifest.actions[0];
  action.decision = {survivorSourceId: 'icu', counterStrategy: {mode: 'sum'}};
  assert.deepEqual(
    Object.fromEntries(Object.entries(resultDataForAction(action)).filter(([key]) => key.endsWith('beds'))),
    {total_beds: 6, held_beds: 2, admitted_beds: 1},
  );
  action.decision.counterStrategy = {
    mode: 'explicit', values: {total_beds: 7, held_beds: 2, admitted_beds: 3},
  };
  assert.equal(resultDataForAction(action).total_beds, 7);
  action.decision.counterStrategy.values.total_beds = 4;
  assert.throws(() => resultDataForAction(action), /exceed total inventory/);
});

test('a single noncanonical document gets a safe rename decision', () => {
  const manifest = createManifest({projectId: 'project-1', documents: [bed('legacy-icu')], bookings: []});
  assert.deepEqual(manifest.actions[0].decision, {
    survivorSourceId: 'legacy-icu', counterStrategy: {mode: 'survivor'},
  });
  assert.doesNotThrow(() => validateDecision(manifest.actions[0]));
});
