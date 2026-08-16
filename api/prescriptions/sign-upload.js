// POST /api/prescriptions/sign-upload
// Body: { bookingId, contentType }
// Auth: Authorization: Bearer <Firebase ID token>
// Returns signed Cloudinary upload params scoped to prescriptions/<uid>/<bookingId>.
const { verifyIdToken } = require('../_lib/firebase');
const {
  withApi,
  sendJson,
  readJsonBody,
  getBearerToken,
  requireBookingId,
  requireContentType,
  buildSignedUpload,
} = require('../_lib/util');

module.exports = withApi(['POST'], async (req, res) => {
  const token = getBearerToken(req);
  const decoded = await verifyIdToken(token);
  const uid = decoded.uid;

  const body = await readJsonBody(req);
  const bookingId = requireBookingId(body.bookingId);
  requireContentType(body.contentType);

  const upload = buildSignedUpload({ uid, bookingId });

  return sendJson(res, 200, {
    upload,
    publicId: upload.publicId,
  });
});
