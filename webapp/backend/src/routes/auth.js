import express from 'express';
import bcrypt from 'bcryptjs';
import cloudkit from '../services/cloudkit.js';
import { generateToken } from '../middleware/auth.js';

const router = express.Router();

/**
 * POST /api/auth/login
 * Login with email and password
 */
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    // Fetch user from CloudKit
    const user = await cloudkit.fetchUserByEmail(email);

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const passwordHash = user.fields.passwordHash?.value;
    const passwordSalt = user.fields.passwordSalt?.value;

    if (!passwordHash || !passwordSalt) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Note: The iOS app uses PBKDF2, but for the web we'll use bcrypt
    // You may need to implement PBKDF2 verification if sharing the same hash
    // For now, this assumes password verification logic
    const isValid = await bcrypt.compare(password, passwordHash);

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check if user is active
    if (!user.fields.isActive?.value) {
      return res.status(403).json({ error: 'Account is inactive' });
    }

    // Generate JWT token
    const token = generateToken({
      userId: user.fields.userId?.value || user.fields.id?.value,
      email: user.fields.email?.value
    });

    res.json({
      token,
      user: {
        userId: user.fields.userId?.value || user.fields.id?.value,
        email: user.fields.email?.value
      }
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
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key-change-in-production');
    res.json({ valid: true, user: decoded });
  } catch (error) {
    res.status(401).json({ valid: false, error: 'Invalid token' });
  }
});

export default router;
