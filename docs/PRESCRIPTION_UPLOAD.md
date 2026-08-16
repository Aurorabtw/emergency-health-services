# Secure Prescription Uploads (Vercel + Cloudinary)

This adds an optional, more secure prescription pipeline that moves images out of
Firestore blobs into **private Cloudinary storage**, fronted by a thin **Vercel**
serverless API. The Cloudinary API secret and the Firebase Admin key stay on the
server; the browser never sees them.

If `PRESCRIPTION_API_URL` is **not** set at build time, the app transparently
keeps the old inline Firestore-blob flow, so nothing breaks before you finish
this setup.

## Flow

```
Flutter app
  │  POST /api/prescriptions/sign-upload   (Firebase ID token)
  ▼
Vercel ── verify token ── sign upload params (api_secret stays here)
  │
  ▼
Flutter uploads the image bytes DIRECTLY to Cloudinary  (type: authenticated / private)
  │  POST /api/prescriptions/finalize      (token + bookingId)
  ▼
Vercel ── confirm the upload exists ── write prescription_assets/{bookingId} (Admin SDK)
  │
  ▼
Flutter creates booking_requests/{bookingId} with prescription_asset_id
  │  (Firestore rules verify the booking references the backend-written asset)
  ▼
Viewing:  GET /api/prescriptions/view?bookingId=   → owner/admin check → short-lived signed URL
Deleting: DELETE /api/prescriptions/delete?bookingId= → authorize → Cloudinary destroy + metadata delete
```

Ordering note: the image is uploaded and finalized **before** the booking is
created, so a prescription is still mandatory at booking-create time (the
Firestore rules reject a bed/blood/ambulance booking whose `prescription_asset_id`
does not point at an existing, matching, backend-written asset).

## What lives where

```
api/
  package.json            node 20.x · cloudinary ^2.5.1 · firebase-admin ^13.2.0
  .env.example            documents the env var NAMES (no secrets committed)
  _lib/
    cloudinary.js         Cloudinary config from env (secret never returned)
    firebase.js           Admin init from FIREBASE_SERVICE_ACCOUNT_JSON + verifyIdToken(checkRevoked)
    util.js               CORS, body/token parsing, signing, role authorization
  prescriptions/
    sign-upload.js        POST  → signed upload params for prescriptions/{uid}/{bookingId}
    finalize.js           POST  → verify Cloudinary asset + write prescription_assets/{bookingId}
    view.js               GET   → owner/admin/super check → short-lived signed URL
    delete.js             DELETE→ authorize → Cloudinary destroy + metadata delete
vercel.json               deploys only /api as functions
.vercelignore             keeps the Flutter source out of the Vercel deploy
```

Client side: `lib/config/app_config.dart`, `lib/services/prescription_api_service.dart`,
plus branches in `lib/providers/booking_provider.dart` and the display widgets.

## 1. Create the accounts / keys (only you can do this)

1. **Cloudinary** (free tier is enough): sign up, then from the dashboard copy
   `Cloud name`, `API Key`, `API Secret`.
2. **Firebase service account** — use a **dedicated least-privilege** account,
   not the default owner key:
   - Firebase Console → Project Settings → **Service accounts** → Generate new
     private key (downloads a JSON file), OR in Google Cloud IAM create a service
     account with roles **Firebase Authentication Viewer** + **Cloud Datastore
     User** and generate a key.
   - You will paste the whole JSON as a single-line string.

> These are secrets. Never commit them. `.gitignore` already blocks `api/.env`,
> `*-service-account*.json`, and `serviceAccount*.json`.

## 2. Set Vercel environment variables

In the Vercel project → Settings → Environment Variables (Production + Preview):

| Name | Value |
|------|-------|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | the entire service-account JSON on one line |
| `CLOUDINARY_CLOUD_NAME` | your Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | your Cloudinary API key |
| `CLOUDINARY_API_SECRET` | your Cloudinary API secret |
| `PRESCRIPTION_CORS_ORIGIN` | comma-separated browser origins allowed to call the API, e.g. `https://health-hub-sdp4.web.app,https://health-hub-sdp4.firebaseapp.com,http://localhost:5000` |

See `api/.env.example` for the exact shape (and for local `vercel dev`).

## 3. Deploy the API to Vercel

- Import this repo as a Vercel project.
- **Root Directory:** repo root (so Vercel auto-routes the `/api` folder).
- **Framework Preset:** Other.
- `vercel.json` sets `installCommand` to `npm install --prefix api` and deploys
  only the functions; the Flutter app is **not** served from Vercel.

> Verify after the first deploy: hit `POST /api/prescriptions/sign-upload` without
> a token and confirm you get `401`. If a function reports a missing module,
> Vercel didn't pick up `api/node_modules` — move `cloudinary` and
> `firebase-admin` into the **root** `package.json` dependencies and redeploy.

## 4. Point the Flutter app at the API

Build/run with the gateway URL:

```bash
flutter run -d chrome --dart-define=PRESCRIPTION_API_URL=https://YOUR-PROJECT.vercel.app
```

```bash
flutter build web --dart-define=PRESCRIPTION_API_URL=https://YOUR-PROJECT.vercel.app
```

Then update the **CSP** so the browser may reach the API. In `firebase.json`,
replace the `https://YOUR-PROJECT.vercel.app` placeholder in `connect-src` with
your real Vercel origin, and redeploy hosting:

```bash
firebase deploy --only hosting
```

(`api.cloudinary.com` and `res.cloudinary.com` are already allow-listed.)

## 5. Deploy the updated Firestore rules

```bash
firebase deploy --only firestore:rules
```

New in `firestore.rules`:
- `prescription_assets/{id}` — readable by the owner / responsible service admin /
  super admin; **all client writes denied** (only the Admin SDK writes it).
- Bed/blood/ambulance booking-create now accepts `prescription_asset_id` as an
  alternative to the legacy `prescription_document_id`, and verifies it against
  the backend-written asset. Legacy blob bookings are unchanged.

## Security properties

- Cloudinary `api_secret` and the Firebase Admin key never leave the server.
- Uploads are **signed**, pinned to `prescriptions/{uid}/{bookingId}`, private
  (`type: authenticated`), and re-encoded on ingest (drops EXIF/GPS) with a size
  cap.
- `finalize` derives the `public_id` from the **token**, not client input, and
  confirms the asset exists before recording it.
- Images are reachable only through **short-lived signed URLs** (~15 min) gated
  by an owner/admin authorization check.
- ID tokens are verified with `checkRevoked`, honoring account revocation.

## Not yet verified in this environment (please check)

- **Cloudinary signed-upload parameters.** The signing code could not be run
  here. Do one real upload end to end and confirm Cloudinary accepts the
  signature; if it returns `401 Invalid Signature`, the set of signed fields in
  `api/_lib/util.js#buildSignedUpload` must exactly match what the client
  forwards (it currently does, but only a live upload proves it).
- **Firestore rules tests.** `npm test` needs **JDK 21+** (this machine has Java
  8). Run `npm test` after installing a modern JDK to confirm the additive rule
  changes pass, including the new `prescription_assets` path.

## Known limitations (acceptable for the SDP scope)

- Rate limiting is not implemented on the API (stateless functions). Add
  Upstash/Redis or a Firestore counter if abuse is a concern.
- If an admin deletes an asset-based booking directly in Firestore (e.g. the
  "clear terminal requests" action), the client makes a best-effort API call to
  delete the Cloudinary asset first; a failure there can orphan the image.
  Prefer the API delete, or run a periodic Cloudinary cleanup.
