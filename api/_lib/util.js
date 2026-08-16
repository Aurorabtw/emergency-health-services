// Shared helpers for the prescription API: CORS, request parsing, auth extraction,
// Cloudinary signing, and role-based authorization.
const { getCloudinary } = require('./cloudinary');

const CONTENT_TYPE_TO_FORMAT = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

const FORMAT_TO_CONTENT_TYPE = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
};

const ALLOWED_BOOKING_TYPES = ['bed', 'blood', 'ambulance'];

// Cloudinary charges you for stored bytes; prescriptions are small documents.
const MAX_ASSET_BYTES = 8 * 1024 * 1024;

// How long a signed view URL stays valid.
const VIEW_URL_TTL_SECONDS = 15 * 60;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function getAllowedOrigins() {
  return (process.env.PRESCRIPTION_CORS_ORIGIN || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}

// Sets CORS headers when the caller's Origin is explicitly allow-listed.
// Returns true when the request is a preflight that the caller already answered.
function applyCors(req, res) {
  const origin = req.headers.origin;
  const allowed = getAllowedOrigins();
  if (origin && allowed.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    res.setHeader(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    res.setHeader('Access-Control-Max-Age', '600');
  }
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    res.end();
    return true;
  }
  return false;
}

function sendJson(res, status, body) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
}

// Wraps a handler with CORS, method-not-allowed guarding, and JSON error mapping.
function withApi(allowedMethods, handler) {
  return async (req, res) => {
    if (applyCors(req, res)) return;
    if (!allowedMethods.includes(req.method)) {
      res.setHeader('Allow', allowedMethods.join(', '));
      return sendJson(res, 405, { error: 'Method not allowed.' });
    }
    try {
      await handler(req, res);
    } catch (err) {
      if (err instanceof HttpError) {
        return sendJson(res, err.status, { error: err.message });
      }
      // Never leak internals (stack traces, secret-config messages) to clients.
      console.error('Prescription API error:', err);
      return sendJson(res, 500, { error: 'Internal error.' });
    }
  };
}

async function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw);
  } catch (_) {
    throw new HttpError(400, 'Request body must be valid JSON.');
  }
}

function getBearerToken(req) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new HttpError(401, 'Missing bearer token.');
  }
  return match[1].trim();
}

function requireString(value, name, { max = 512 } = {}) {
  if (typeof value !== 'string' || value.length === 0 || value.length > max) {
    throw new HttpError(400, `Invalid ${name}.`);
  }
  return value;
}

// Booking ids are client-generated UUIDs / Firestore ids. Keep the character set
// tight so it is safe to embed in a Cloudinary public_id path.
function requireBookingId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new HttpError(400, 'Invalid bookingId.');
  }
  return value;
}

function requireContentType(value) {
  if (!CONTENT_TYPE_TO_FORMAT[value]) {
    throw new HttpError(400, 'Unsupported image type.');
  }
  return value;
}

function requireBookingType(value) {
  if (!ALLOWED_BOOKING_TYPES.includes(value)) {
    throw new HttpError(400, 'Invalid bookingType.');
  }
  return value;
}

// Per-user folder so a valid token can only ever write under its own uid.
function publicIdFor(uid, bookingId) {
  return `prescriptions/${uid}/${bookingId}`;
}

function formatToContentType(format) {
  return FORMAT_TO_CONTENT_TYPE[String(format || '').toLowerCase()] || null;
}

// Builds signed, single-use upload parameters. The client POSTs these plus the
// file straight to Cloudinary; the signature pins public_id, private delivery
// type, and an incoming transform that re-encodes (dropping EXIF/GPS) and caps
// dimensions. The api_secret is only used here to sign — it is never returned.
function buildSignedUpload({ uid, bookingId }) {
  const cloudinary = getCloudinary();
  const publicId = publicIdFor(uid, bookingId);
  const timestamp = Math.floor(Date.now() / 1000);
  const paramsToSign = {
    public_id: publicId,
    timestamp,
    type: 'authenticated',
    overwrite: 'true',
    invalidate: 'true',
    allowed_formats: 'jpg,png,webp',
    transformation: 'c_limit,w_2000,h_2000,q_auto',
  };
  const signature = cloudinary.utils.api_sign_request(
    paramsToSign,
    cloudinary.config().api_secret,
  );
  return {
    url: `https://api.cloudinary.com/v1_1/${cloudinary.config().cloud_name}/image/upload`,
    fields: {
      ...paramsToSign,
      timestamp: String(timestamp),
      api_key: cloudinary.config().api_key,
      signature,
    },
    publicId,
  };
}

// Short-lived, signed URL to the private original. Only reachable while the
// expiry token is valid.
function buildSignedViewUrl(publicId, format) {
  const cloudinary = getCloudinary();
  const expiresAt = Math.floor(Date.now() / 1000) + VIEW_URL_TTL_SECONDS;
  const url = cloudinary.utils.private_download_url(
    publicId,
    (format || 'jpg').toLowerCase(),
    {
      type: 'authenticated',
      resource_type: 'image',
      attachment: false,
      expires_at: expiresAt,
    },
  );
  return { url, expiresAt };
}

// Mirrors the Firestore rules: an owner always qualifies; otherwise only the
// super admin, or the service admin assigned to the booking's organization.
function canManageAsset(userDoc, asset) {
  if (!userDoc) return false;
  const role = userDoc.role;
  if (role === 'super_admin') return true;
  if (!userDoc.organization_id || userDoc.organization_id !== asset.organization_id) {
    return false;
  }
  switch (asset.booking_type) {
    case 'bed':
      return role === 'bed_admin' || role === 'hospital_admin';
    case 'blood':
      return role === 'blood_bank_admin';
    case 'ambulance':
      return role === 'ambulance_admin';
    default:
      return false;
  }
}

module.exports = {
  HttpError,
  MAX_ASSET_BYTES,
  applyCors,
  withApi,
  sendJson,
  readJsonBody,
  getBearerToken,
  requireString,
  requireBookingId,
  requireContentType,
  requireBookingType,
  publicIdFor,
  formatToContentType,
  buildSignedUpload,
  buildSignedViewUrl,
  canManageAsset,
};
