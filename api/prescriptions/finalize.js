// POST /api/prescriptions/finalize
// Body: { bookingId, organizationId, bookingType }
// Auth: Authorization: Bearer <Firebase ID token>
//
// Confirms the image actually landed in Cloudinary under the caller's own folder
// (the public_id is derived server-side, never trusted from the client), then
// writes prescription_assets/<bookingId> with the Admin SDK. The client creates
// the booking afterward; the Firestore rules bind booking -> this asset.
const { verifyIdToken, db, FieldValue } = require('../_lib/firebase');
const { getCloudinary } = require('../_lib/cloudinary');
const {
  withApi,
  sendJson,
  readJsonBody,
  getBearerToken,
  HttpError,
  MAX_ASSET_BYTES,
  requireBookingId,
  requireString,
  requireBookingType,
  publicIdFor,
  formatToContentType,
} = require('../_lib/util');

module.exports = withApi(['POST'], async (req, res) => {
  const token = getBearerToken(req);
  const decoded = await verifyIdToken(token);
  const uid = decoded.uid;

  const body = await readJsonBody(req);
  const bookingId = requireBookingId(body.bookingId);
  const organizationId = requireString(body.organizationId, 'organizationId', {
    max: 200,
  });
  const bookingType = requireBookingType(body.bookingType);

  const publicId = publicIdFor(uid, bookingId);
  const cloudinary = getCloudinary();

  // The upload must already exist; otherwise nothing to finalize.
  let resource;
  try {
    resource = await cloudinary.api.resource(publicId, {
      type: 'authenticated',
      resource_type: 'image',
    });
  } catch (_) {
    throw new HttpError(
      404,
      'No uploaded image was found for this booking. Upload before finalizing.',
    );
  }

  if (typeof resource.bytes === 'number' && resource.bytes > MAX_ASSET_BYTES) {
    // Reject and delete oversized uploads so they cannot linger in storage.
    await cloudinary.uploader
      .destroy(publicId, { type: 'authenticated', resource_type: 'image' })
      .catch(() => {});
    throw new HttpError(413, 'Prescription image is too large.');
  }

  const contentType = formatToContentType(resource.format);
  if (!contentType) {
    await cloudinary.uploader
      .destroy(publicId, { type: 'authenticated', resource_type: 'image' })
      .catch(() => {});
    throw new HttpError(415, 'Unsupported image format.');
  }

  const ref = db().collection('prescription_assets').doc(bookingId);
  const existing = await ref.get();
  if (existing.exists && existing.data().user_id !== uid) {
    throw new HttpError(403, 'This booking already has a prescription owned by another user.');
  }

  await ref.set({
    booking_id: bookingId,
    user_id: uid,
    organization_id: organizationId,
    booking_type: bookingType,
    content_type: contentType,
    cloudinary_public_id: publicId,
    cloudinary_resource_type: 'image',
    format: resource.format,
    bytes: typeof resource.bytes === 'number' ? resource.bytes : null,
    width: typeof resource.width === 'number' ? resource.width : null,
    height: typeof resource.height === 'number' ? resource.height : null,
    uploaded_by: uid,
    created_at: FieldValue.serverTimestamp(),
  });

  return sendJson(res, 200, {
    assetId: bookingId,
    publicId,
    contentType,
  });
});
