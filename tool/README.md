# Firebase Reconciliation Tool

This directory is a self-contained, read-first Node utility for production audits and reviewed inventory reconciliation. It never reads credential files directly: Firebase Admin uses `GOOGLE_APPLICATION_CREDENTIALS` when set, otherwise Application Default Credentials (ADC). Do not put service-account JSON in this directory or pass credentials on the command line.

## Safety Model

- Every command is read-only except `apply`.
- `apply` requires all of `--manifest`, the literal `--apply` switch, and the exact SHA-256 from `hash` as `--confirm-hash`.
- Every remote command requires an explicit `--project-id`; a manifest is also pinned to that project ID.
- Firebase Auth/Firestore emulator environment variables are rejected.
- Reports contain only project IDs, UIDs/document IDs, counts, and issue codes. The tool selects only reference fields from bookings and never reads prescription documents or logs patient/profile contents.
- Inventory source data and booking-reference IDs are hashed/captured in the manifest. Apply refuses drift instead of guessing.
- Booking references move in batches of 450. Inventory consolidation and source deletion happen in a final transaction that rechecks counters and late references and stays below Firestore's 500-write limit.
- Completed actions are idempotent. An interrupted action can be rerun with the same reviewed manifest unless live data changed; on drift, generate and review a new manifest.

Run from this directory:

```sh
npm install
npm test
npm run lint
```

Use a least-privilege trusted administrator identity through ADC. Audit before creating a manifest:

```sh
node src/cli.js audit-profiles --project-id PROJECT --output auth-profiles.json
node src/cli.js audit-revocations --project-id PROJECT --output revocations.json
node src/cli.js audit-inventory --project-id PROJECT --output inventory.json
node src/cli.js audit --project-id PROJECT --output complete-audit.json
```

Audit commands exit `2` when findings exist, `0` when clean, and `1` on operational failure. Auth/profile audit reports Auth identities missing `users/{uid}` and orphan profiles. Revocation audit compares `access_revocations/{uid}` with the profile flag, timestamp, actor, and ledger ID. Inventory audit detects invalid counters/values, duplicate logical inventory, and noncanonical IDs per organization.

## Manifest Review

Generate a deterministic manifest. It has no generated timestamp, and repeated generation over the same snapshot produces the same canonical JSON and hash.

```sh
node src/cli.js manifest --project-id PROJECT --output migration.json
```

A single noncanonical document gets a `survivor` rename decision. Duplicate groups deliberately contain unresolved values:

```json
"decision": {
  "survivorSourceId": null,
  "counterStrategy": null
}
```

For every duplicate, an administrator must choose a listed source document as `survivorSourceId` and choose one counter strategy:

```json
{"mode":"survivor"}
```

Keeps all inventory counters from the selected survivor. This can discard counters from the other documents and should be used only when those documents are known duplicates of the same physical stock.

```json
{"mode":"sum"}
```

Sums total and held/admitted or held/issued counters from every source. Use only when each document represents distinct physical inventory.

```json
{
  "mode": "explicit",
  "values": {"total_beds": 12, "held_beds": 2, "admitted_beds": 4}
}
```

For blood stock, explicit fields are `total_units`, `held_units`, and `issued_units`. Blood totals must be non-negative integers; bed totals must be positive integers. Neither can be below occupied/held sums. The selected survivor supplies non-counter fields such as price and hold duration. Review those differences before applying. Do not edit captured `documents`, hashes, targets, references, or project ID.

`blockingIssues` must be empty. Invalid inventory and canonical-ID collisions cannot be resolved safely by this tool; correct or separately adjudicate them, then regenerate the manifest.

After review, calculate the hash of the exact edited file:

```sh
node src/cli.js hash --manifest migration.json
```

Changing any byte-level JSON value after review changes the canonical content hash. Formatting and object-key order do not affect it.

## Apply And Verify

Do not apply while administrators are actively changing the affected inventory. First rerun audits or regenerate the manifest, review it, then use the hash printed by `hash`:

```sh
node src/cli.js apply --project-id PROJECT --manifest migration.json --apply --confirm-hash SHA256
node src/cli.js verify --project-id PROJECT --manifest migration.json --output verification.json
```

Apply creates a canonical target before changing references, updates every captured `booking_requests` inventory ID, and only then atomically writes reviewed counters and removes old documents. It refuses unresolved duplicate decisions, changed inventory, changed booking-reference sets, project mismatch, conflicting canonical targets, invalid counters, or an operation that cannot fit safely within Firestore limits.

Verification checks the canonical target data and reviewed counters, confirms old source documents are gone, and confirms the reviewed booking-ID set points to the target. It exits `2` if a postcondition fails. Running verification long after migration may report legitimate target-data drift or later booking cleanup as a mismatch; retain the immediate apply/verification output as the migration record.
