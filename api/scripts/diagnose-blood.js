// Diagnoses why a blood booking is rejected by the Firestore rules, by reading
// the REAL data with the Firebase Admin key and checking each rule condition.
//
// Usage (from the project folder):
//   node api/scripts/diagnose-blood.js "<serviceAccount.json path>" "<Blood Bank name>" "<Destination Hospital name>"
//
// Example:
//   node api/scripts/diagnose-blood.js "D:\health-hub-sdp4-firebase-adminsdk-fbsvc-52467d64da.json" "Red Crescent Blood Center" "Islami Bank Hospital Mirpur"

const admin = require('firebase-admin');

const saPath = process.argv[2];
const bankName = process.argv[3];
const hospitalName = process.argv[4];

if (!saPath || !bankName || !hospitalName) {
  console.error(
    'Usage: node api/scripts/diagnose-blood.js "<serviceAccount.json>" "<Blood Bank name>" "<Hospital name>"',
  );
  process.exit(1);
}

admin.initializeApp({
  // eslint-disable-next-line import/no-dynamic-require, global-require
  credential: admin.credential.cert(require(require('path').resolve(saPath))),
});
const db = admin.firestore();

const mark = (ok) => (ok ? '✅' : '❌');

async function findOrg(name) {
  const snap = await db
    .collection('organizations')
    .where('name', '==', name)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
}

async function checkOrg(label, name, expectedType) {
  console.log(`\n=== ${label}: "${name}" ===`);
  const org = await findOrg(name);
  if (!org) {
    console.log(`${mark(false)} NOT FOUND with this EXACT name (name mismatch → rule fails)`);
    return null;
  }
  console.log(`id: ${org.id}`);
  console.log(`${mark(org.type === expectedType)} type = "${org.type}" (must be "${expectedType}")`);
  console.log(`${mark(org.verified === true)} verified = ${org.verified} (must be true, boolean)`);
  console.log(`${mark(org.archived !== true)} archived = ${org.archived} (must NOT be true)`);
  return org;
}

async function main() {
  const bank = await checkOrg('BLOOD BANK', bankName, 'blood_bank');

  if (bank) {
    console.log('\n--- blood stock for this bank ---');
    const stock = await db
      .collection('organizations')
      .doc(bank.id)
      .collection('blood_stock')
      .get();
    if (stock.empty) console.log('❌ no blood_stock documents found');
    stock.forEach((d) => {
      const s = d.data();
      const total = s.total_units;
      const held = s.held_units;
      const issued = s.issued_units;
      const avail = (total || 0) - (held || 0) - (issued || 0);
      const intsOk = [total, held, issued].every(Number.isInteger);
      console.log(
        `${s.blood_type}: total=${total} held=${held} issued=${issued} → avail=${avail} | fee=${s.processing_fee_per_unit} ` +
          `${mark(intsOk)} counts are whole numbers | ${mark(typeof s.processing_fee_per_unit === 'number')} fee is a number`,
      );
    });
  }

  await checkOrg('DESTINATION HOSPITAL', hospitalName, 'hospital');

  console.log('\n=== most recent prescription_asset (from your last attempt) ===');
  const assets = await db
    .collection('prescription_assets')
    .orderBy('created_at', 'desc')
    .limit(1)
    .get();
  if (assets.empty) {
    console.log('none found');
  } else {
    const a = assets.docs[0].data();
    console.log(`booking_type = "${a.booking_type}"  organization_id = "${a.organization_id}"`);
    console.log(`user_id = "${a.user_id}"`);
    if (bank) {
      console.log(
        `${mark(a.organization_id === bank.id)} asset.organization_id matches the blood bank id`,
      );
    }
    console.log(`${mark(a.booking_type === 'blood')} asset.booking_type is "blood"`);
  }

  console.log('\nAny ❌ above is the reason the booking is rejected.');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
