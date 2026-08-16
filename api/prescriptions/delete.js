// DELETE /api/prescriptions/delete?bookingId=<id>
// Auth: Authorization: Bearer <Firebase ID token>
//
// Destroys the Cloudinary asset and its metadata. Mirrors the Firestore delete
// rule: allowed for the owner/responsible admin only once the booking is closed
// (terminal) or already gone; the super admin may always clean up.
const { verifyIdToken, db, FieldValue } = require('../_lib/firebase');
const { getCloudinary } = require('../_lib/cloudinary');
const {
  withApi,
  sendJson,
  getBearerToken,
  HttpError,
  requireBookingId,
  canManageAsset,
} = require('../_lib/util');

const TERMINAL_STATUSES = ['rejected', 'expired', 'discharged'];

function bookingIsTerminal(booking) {
  if (!booking) return true; // booking already deleted → cleanup allowed
  if (TERMINAL_STATUSES.includes(booking.status)) return true;
  return booking.type !== 'bed' && booking.status === 'admitted';
}

module.exports = withApi(['DELETE'], async (req, res) => {
  const token = getBearerToken(req);
  const decoded = await verifyIdToken(token);
  const uid = decoded.uid;

  const bookingId = requireBookingId((req.query && req.query.bookingId) || '');
  const assetRef = db().collection('prescription_assets').doc(bookingId);
  const snap = await assetRef.get();
  if (!snap.exists) {
    return sendJson(res, 200, { ok: true, alreadyDeleted: true });
  }
  const asset = snap.data();

  let userDoc = null;
  const isOwner = asset.user_id === uid;
  if (!isOwner) {
    const userSnap = await db().collection('users').doc(uid).get();
    userDoc = userSnap.data() || null;
    if (!canManageAsset(userDoc, asset)) {
      throw new HttpError(403, 'Not authorized to remove this prescription.');
    }
  }

  const bookingSnap = await db().collection('booking_requests').doc(bookingId).get();
  const booking = bookingSnap.exists ? bookingSnap.data() : null;
  const isSuperAdmin = userDoc && userDoc.role === 'super_admin';
  if (!bookingIsTerminal(booking) && !isSuperAdmin) {
    throw new HttpError(
      409,
      'Prescription can only be removed after the booking is closed.',
    );
  }

  const cloudinary = getCloudinary();
  await cloudinary.uploader.destroy(asset.cloudinary_public_id, {
    type: 'authenticated',
    resource_type: 'image',
    invalidate: true,
  });
  await assetRef.delete();

  if (bookingSnap.exists && booking && booking.prescription_asset_id === bookingId) {
    await bookingSnap.ref
      .update({ prescription_asset_id: FieldValue.delete() })
      .catch(() => {});
  }

  return sendJson(res, 200, { ok: true });
});
