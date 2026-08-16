// GET /api/prescriptions/view?bookingId=<id>
// Auth: Authorization: Bearer <Firebase ID token>
//
// Returns a short-lived signed URL to the private prescription image, but only
// for the owner, the responsible service admin, or a super admin.
const { verifyIdToken, db } = require('../_lib/firebase');
const {
  withApi,
  sendJson,
  getBearerToken,
  HttpError,
  requireBookingId,
  canManageAsset,
  buildSignedViewUrl,
} = require('../_lib/util');

module.exports = withApi(['GET'], async (req, res) => {
  const token = getBearerToken(req);
  const decoded = await verifyIdToken(token);
  const uid = decoded.uid;

  const bookingId = requireBookingId((req.query && req.query.bookingId) || '');

  const snap = await db().collection('prescription_assets').doc(bookingId).get();
  if (!snap.exists) {
    throw new HttpError(404, 'Prescription not found.');
  }
  const asset = snap.data();

  if (asset.user_id !== uid) {
    const userSnap = await db().collection('users').doc(uid).get();
    if (!canManageAsset(userSnap.data(), asset)) {
      throw new HttpError(403, 'Not authorized to view this prescription.');
    }
  }

  const { url, expiresAt } = buildSignedViewUrl(asset.cloudinary_public_id, asset.format);
  return sendJson(res, 200, {
    url,
    expiresAt,
    contentType: asset.content_type,
  });
});
