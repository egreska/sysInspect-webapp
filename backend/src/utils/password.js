import crypto from 'crypto';

/**
 * Verify password using PBKDF2-HMAC-SHA256 to match iOS UserManager.
 * iOS uses: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 100_000 iterations, keyLength 32.
 * Hash and salt stored as base64; salt is Binary in Core Data, CloudKit returns base64 string.
 */
const PBKDF2_ITERATIONS = 100_000;
const KEY_LENGTH = 32;
const DIGEST = 'sha256';

/**
 * Normalize salt to a Buffer (CloudKit BYTES = base64 string; handle wrappers).
 */
function saltToBuffer(salt) {
  if (!salt) return null;
  if (Buffer.isBuffer(salt)) return salt.length ? salt : null;
  if (typeof salt === 'string') {
    const s = salt.trim();
    if (!s) return null;
    const buf = Buffer.from(s, 'base64');
    return buf.length ? buf : null;
  }
  if (salt && typeof salt.value !== 'undefined') return saltToBuffer(salt.value);
  return null;
}

/**
 * @param {string} password - Plain text password (UTF-8, matching iOS Data(password.utf8))
 * @param {string} storedHashBase64 - Stored hash (base64) from CloudKit CD_passwordHash
 * @param {string|Buffer|{value: string}} salt - Salt from CloudKit CD_passwordSalt
 * @returns {boolean}
 */
export function verifyPasswordPBKDF2(password, storedHashBase64, salt) {
  if (!password || typeof password !== 'string') return false;
  const rawHash = typeof storedHashBase64 === 'string' ? storedHashBase64 : (storedHashBase64?.value ?? '');
  const hash = (typeof rawHash === 'string' ? rawHash : '').trim();
  if (!hash) return false;

  const saltBuffer = saltToBuffer(salt);
  if (!saltBuffer) return false;

  const derived = crypto.pbkdf2Sync(
    password,
    saltBuffer,
    PBKDF2_ITERATIONS,
    KEY_LENGTH,
    DIGEST
  );
  const derivedBase64 = derived.toString('base64');

  // Use constant-time comparison to prevent timing attacks
  return crypto.timingSafeEqual(
    Buffer.from(derivedBase64),
    Buffer.from(hash)
  );
}
