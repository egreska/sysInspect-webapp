import crypto from 'crypto';

/**
 * Verify password using PBKDF2-HMAC-SHA256 to match iOS UserManager.
 * iOS uses: PBKDF2, 100_000 iterations, keyLength 32, hash stored as base64.
 * Salt is stored as Binary (Data) in Core Data; CloudKit may return as base64 string.
 */
const PBKDF2_ITERATIONS = 100_000;
const KEY_LENGTH = 32;
const DIGEST = 'sha256';

/**
 * @param {string} password - Plain text password
 * @param {string} storedHashBase64 - Stored hash (base64) from CloudKit CD_passwordHash
 * @param {string|Buffer} salt - Salt from CloudKit CD_passwordSalt (base64 string or Buffer)
 * @returns {boolean}
 */
export function verifyPasswordPBKDF2(password, storedHashBase64, salt) {
  if (!password || !storedHashBase64 || !salt) return false;
  let saltBuffer;
  if (Buffer.isBuffer(salt)) {
    saltBuffer = salt;
  } else if (typeof salt === 'string') {
    saltBuffer = Buffer.from(salt, 'base64');
  } else {
    return false;
  }
  const derived = crypto.pbkdf2Sync(
    password,
    saltBuffer,
    PBKDF2_ITERATIONS,
    KEY_LENGTH,
    DIGEST
  );
  const derivedBase64 = derived.toString('base64');
  return derivedBase64 === storedHashBase64;
}
