/**
 * Global error handling middleware
 * Note: req and next parameters are required for Express error middleware signature
 */
export const errorHandler = (err, _req, res, _next) => {
  console.error('Error:', err);

  // Default error
  let status = err.status || 500;
  let message = err.message || 'Internal Server Error';

  // Validation errors
  if (err.name === 'ValidationError') {
    status = 400;
    message = err.message;
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    status = 401;
    message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    status = 401;
    message = 'Token expired';
  }

  // CloudKit errors
  if (err.message && err.message.includes('CloudKit')) {
    status = 502;
    message = 'CloudKit service error';
  }

  // Never expose stack traces to clients - log them server-side instead
  res.status(status).json({
    error: message
  });
};
