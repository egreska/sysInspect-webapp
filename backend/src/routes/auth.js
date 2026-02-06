import express from 'express';
import jwt from 'jsonwebtoken';
import cloudkit from '../services/cloudkit.js';
import { generateToken } from '../middleware/auth.js';
import { verifyPasswordPBKDF2 } from '../utils/password.js';

const router = express.Router();

/**
 * POST /api/auth/login
 * Login with email and password. Uses PBKDF2 verification to match iOS app hashes.
 */
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    // Fetch user from CloudKit (Core Data + CloudKit uses CD_ prefix)
    const user = await cloudkit.fetchUserByEmail(email);

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const passwordHash = user.fields.CD_passwordHash?.value;
    const passwordSalt = user.fields.CD_passwordSalt?.value;

    if (!passwordHash || !passwordSalt) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // iOS app uses PBKDF2-HMAC-SHA256 (100k iterations). Salt may be base64 or buffer.
    const saltValue = typeof passwordSalt === 'string' ? passwordSalt : passwordSalt?.value ?? passwordSalt;
    const isValid = verifyPasswordPBKDF2(password, passwordHash, saltValue);

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check if user is active
    if (!user.fields.CD_isActive?.value) {
      return res.status(403).json({ error: 'Account is inactive' });
    }

    // Use consistent userId (string) for JWT and customer queries. iOS uses UUID.
    const rawUserId = user.fields.CD_userId?.value ?? user.fields.CD_id?.value;
    const userId = rawUserId != null ? String(rawUserId) : null;
    const userEmail = user.fields.CD_email?.value;

    if (!userId || !userEmail) {
      return res.status(500).json({ error: 'User record incomplete' });
    }

    const token = generateToken({ userId, email: userEmail });

    res.json({
      token,
      user: { userId, email: userEmail }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/verify
 * Verify JWT token
 */
router.post('/verify', async (req, res) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token required' });
  }

  try {
    const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
    const decoded = jwt.verify(token, JWT_SECRET);
    res.json({ valid: true, user: decoded });
  } catch (error) {
    res.status(401).json({ valid: false, error: 'Invalid token' });
  }
});

export default router;
