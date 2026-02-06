import { create } from 'zustand';
import type { User } from '../types';
import { authAPI } from '../services/api';

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  checkAuth: () => Promise<void>;
}

// Safe localStorage access with error handling
const getStoredToken = (): string | null => {
  try {
    return localStorage.getItem('token');
  } catch (e) {
    // localStorage not available (e.g., incognito mode, SSR)
    return null;
  }
};

const setStoredToken = (token: string): void => {
  try {
    localStorage.setItem('token', token);
  } catch (e) {
    // Ignore localStorage errors
  }
};

const removeStoredToken = (): void => {
  try {
    localStorage.removeItem('token');
  } catch (e) {
    // Ignore localStorage errors
  }
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: getStoredToken(),
  isAuthenticated: !!getStoredToken(),
  isLoading: false,
  error: null,

  login: async (email: string, password: string) => {
    set({ isLoading: true, error: null });
    try {
      const response = await authAPI.login({ email, password });
      // Reject if we didn't get a real token (e.g. /api routed to frontend and returned HTML)
      if (!response?.token || typeof response.token !== 'string') {
        set({ error: 'Invalid response from server. Check that /api is routed to the backend.', isLoading: false });
        throw new Error('Invalid login response');
      }
      setStoredToken(response.token);
      set({
        user: response.user ?? null,
        token: response.token,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      });
    } catch (error: any) {
      const errorMessage = error.response?.data?.error || error.message || 'Login failed';
      set({
        error: errorMessage,
        isLoading: false,
        isAuthenticated: false,
        user: null,
        token: null
      });
      throw error;
    }
  },

  logout: () => {
    removeStoredToken();
    set({
      user: null,
      token: null,
      isAuthenticated: false,
      error: null,
    });
  },

  checkAuth: async () => {
    const token = getStoredToken();
    if (!token) {
      set({ isAuthenticated: false, token: null, user: null });
      return;
    }

    try {
      const { valid, user } = await authAPI.verify();
      if (valid) {
        set({ user, isAuthenticated: true });
      } else {
        removeStoredToken();
        set({ isAuthenticated: false, token: null, user: null });
      }
    } catch (error) {
      removeStoredToken();
      set({ isAuthenticated: false, token: null, user: null });
    }
  },
}));
