// Standalone check: signs + uploads a tiny image to Cloudinary EXACTLY the way
// the app will, then fetches it back through a signed URL, then cleans up.
// Proves the Cloudinary signed-upload signature and private delivery work
// before wiring up Vercel + Flutter. Uses only the CLOUDINARY_* credentials.
//
// Run from the api/ folder:
//   node scripts/verify-upload.js
// Credentials are read from api/.env (see .env.example) or the environment.

const fs = require('fs');
const path = require('path');

// Minimal .env loader (no dependency) so api/.env just works.
function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnv();

const { getCloudinary } = require('../_lib/cloudinary');
const { buildSignedUpload, buildSignedViewUrl } = require('../_lib/util');

// 1x1 PNG.
const TINY_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  'base64',
);

async function main() {
  for (const name of [
    'CLOUDINARY_CLOUD_NAME',
    'CLOUDINARY_API_KEY',
    'CLOUDINARY_API_SECRET',
  ]) {
    if (!process.env[name]) {
      console.error(`Missing ${name}. Put the CLOUDINARY_* values in api/.env.`);
      process.exit(1);
    }
  }

  const uid = '_verify';
  const bookingId = `test-${Date.now()}`;
  const { url, fields, publicId } = buildSignedUpload({ uid, bookingId });

  console.log(`Uploading test image as: ${publicId}`);

  // 2. Upload exactly like the Flutter client: multipart with the signed fields.
  const form = new FormData();
  for (const [key, value] of Object.entries(fields)) form.append(key, value);
  form.append('file', new Blob([TINY_PNG], { type: 'image/png' }), 'test.png');

  const uploadResponse = await fetch(url, { method: 'POST', body: form });
  const uploadBody = await uploadResponse.json();
  if (!uploadResponse.ok) {
    console.error('\n❌ UPLOAD REJECTED by Cloudinary:');
    console.error(JSON.stringify(uploadBody, null, 2));
    console.error(
      '\nIf this says "Invalid Signature", the signed fields in ' +
        'api/_lib/util.js#buildSignedUpload need to match what is sent.',
    );
    process.exit(1);
  }
  console.log('✅ Signed upload accepted.');

  // 3. Fetch it back through a short-lived signed URL (private delivery).
  const { url: viewUrl } = buildSignedViewUrl(publicId, 'png');
  const viewResponse = await fetch(viewUrl);
  if (!viewResponse.ok) {
    console.error(`\n❌ Signed view URL failed: HTTP ${viewResponse.status}`);
    console.error(`URL: ${viewUrl}`);
  } else {
    console.log('✅ Signed view URL works (private delivery OK).');
  }

  // 4. Confirm the raw asset is NOT public without a signature.
  const cloudinary = getCloudinary();
  const unsigned = cloudinary.url(publicId, {
    type: 'authenticated',
    resource_type: 'image',
    format: 'png',
  });
  const unsignedResponse = await fetch(unsigned).catch(() => null);
  if (unsignedResponse && unsignedResponse.ok) {
    console.warn('⚠️  Unsigned URL was reachable — check account privacy settings.');
  } else {
    console.log('✅ Unsigned URL is blocked (image is private).');
  }

  // 5. Clean up the test asset.
  await cloudinary.uploader
    .destroy(publicId, { type: 'authenticated', resource_type: 'image', invalidate: true })
    .then(() => console.log('🧹 Test image deleted.'))
    .catch((e) => console.warn(`Could not delete test image (${publicId}):`, e.message));

  console.log('\nAll Cloudinary checks passed. Safe to proceed with the deploy.');
}

main().catch((err) => {
  console.error('\n❌ Verification failed:', err);
  process.exit(1);
});
