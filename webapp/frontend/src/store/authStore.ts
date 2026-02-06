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

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: localStorage.getItem('token'),
  isAuthenticated: !!localStorage.getItem('token'),
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
      localStorage.setItem('token', response.token);
      set({
        user: response.user ?? null,
        token: response.token,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      });
    } catch (error: any) {
      const errorMessage = error.response?.data?.error || error.message || 'Login failed';
      set({ error: errorMessage, isLoading: false });
      throw error;
    }
  },

  logout: () => {
    localStorage.removeItem('token');
    set({
      user: null,
      token: null,
      isAuthenticated: false,
    });
  },

  checkAuth: async () => {
    const token = localStorage.getItem('token');
    if (!token) {
      set({ isAuthenticated: false });
      return;
    }

    try {
      const { valid, user } = await authAPI.verify();
      if (valid) {
        set({ user, isAuthenticated: true });
      } else {
        localStorage.removeItem('token');
        set({ isAuthenticated: false, token: null });
      }
    } catch (error) {
      localStorage.removeItem('token');
      set({ isAuthenticated: false, token: null });
    }
  },
}));
