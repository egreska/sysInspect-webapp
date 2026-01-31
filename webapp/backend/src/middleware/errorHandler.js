/**
 * Global error handling middleware
 */
export const errorHandler = (err, req, res, next) => {
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

  res.status(status).json({
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};
