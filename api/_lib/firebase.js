// Firebase Admin initialized from a service-account JSON kept only in Vercel env.
// verifyIdToken(token, true) also rejects revoked/disabled sessions, matching the
// app's account-revocation feature.
const admin = require('firebase-admin');

let app;

function getApp() {
  if (!app) {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not set.');
    }
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(raw);
    } catch (_) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON.');
    }
    app = admin.apps.length
      ? admin.app()
      : admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
  }
  return app;
}

async function verifyIdToken(token) {
  getApp();
  // checkRevoked = true → throws if the session was revoked or the user disabled.
  return admin.auth().verifyIdToken(token, true);
}

function db() {
  getApp();
  return admin.firestore();
}

module.exports = {
  admin,
  getApp,
  verifyIdToken,
  db,
  FieldValue: admin.firestore.FieldValue,
};
