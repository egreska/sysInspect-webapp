/**
 * Production-safe logging: verbose logs only in development.
 * Avoids leaking CloudKit details, record IDs, or asset URLs in production consoles.
 */
const isDev = import.meta.env.DEV;

export const logger = {
  debug: (...args: unknown[]) => {
    if (isDev) console.debug(...args);
  },

  warn: (...args: unknown[]) => {
    if (isDev) console.warn(...args);
  },

  /**
   * In production, logs only a short message. Full errors stay in dev for debugging.
   */
  error: (message: string, err?: unknown) => {
    if (isDev) {
      console.error(message, err);
    } else {
      console.error(message);
    }
  },
};
