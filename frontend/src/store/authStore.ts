import { create } from 'zustand';
import type { User } from '../types';
import {
  setUpAuth,
  whenUserSignsIn,
  whenUserSignsOut,
  type CloudKitUserIdentity,
} from '../services/cloudkit';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  cloudKitReady: boolean;

  initAuth: () => Promise<void>;
  logout: () => Promise<void>;
}

function userIdentityToUser(identity: CloudKitUserIdentity | null): User | null {
  if (!identity) return null;
  const email = identity.lookupInfo?.emailAddress || '';
  const userId = identity.userRecordName || '';
  if (!userId) return null;
  return { userId, email };
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isAuthenticated: false,
  isLoading: true,
  error: null,
  cloudKitReady: false,

  initAuth: async () => {
    set({ isLoading: true, error: null });
    try {
      const identity = await setUpAuth();
      const user = userIdentityToUser(identity);
      set({
        user,
        isAuthenticated: !!user,
        isLoading: false,
        cloudKitReady: true,
        error: null,
      });
      // Listen for sign in/out (long-lived promises - catch to avoid unhandled rejections)
      whenUserSignsIn().then((id) => {
        set({ user: userIdentityToUser(id), isAuthenticated: true });
      }).catch(() => {});
      whenUserSignsOut().then(() => {
        set({ user: null, isAuthenticated: false });
      }).catch(() => {});
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'CloudKit auth failed';
      set({
        error: msg,
        isLoading: false,
        cloudKitReady: true,
        isAuthenticated: false,
        user: null,
      });
    }
  },

  logout: async () => {
    // CloudKit JS doesn't have explicit logout - user uses sign-out button
    // We clear local state; the sign-out button triggers whenUserSignsOut
    set({ user: null, isAuthenticated: false });
  },
}));
