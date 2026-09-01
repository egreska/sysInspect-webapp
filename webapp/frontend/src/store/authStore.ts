import { create } from 'zustand';
import type { User } from '../types';
import {
  setUpAuth,
  whenUserSignsIn,
  whenUserSignsOut,
  triggerSignOut,
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
  checkAuthAfterPopup: () => Promise<void>;
}

function userIdentityToUser(identity: CloudKitUserIdentity | null): User | null {
  if (!identity) return null;
  const email = identity.lookupInfo?.emailAddress || '';
  const userId = identity.userRecordName || '';
  if (!userId) return null;
  return { userId, email };
}

export const useAuthStore = create<AuthState>((set, get) => ({
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
      // Listen for sign in/out (wrap in Promise.resolve - CloudKit may return non-standard thenable)
      Promise.resolve(whenUserSignsIn()).then((id) => {
        set({ user: userIdentityToUser(id), isAuthenticated: true });
      }).catch(() => {});
      Promise.resolve(whenUserSignsOut()).then(() => {
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

  /** Workaround: Apple popup may close without resolving whenUserSignsIn. Re-check auth when window regains focus. */
  checkAuthAfterPopup: async () => {
    if (get().isAuthenticated) return;
    try {
      const identity = await setUpAuth();
      const user = userIdentityToUser(identity);
      if (user) {
        set({ user, isAuthenticated: true });
      }
    } catch {
      // Ignore - user may not have completed sign-in
    }
  },

  logout: async () => {
    // Trigger CloudKit sign-out (clicks the hidden Apple button) so Sign in appears on login page
    triggerSignOut();
    set({ user: null, isAuthenticated: false });
    // Brief delay so CloudKit can process sign-out before we navigate
    await new Promise((r) => setTimeout(r, 100));
  },
}));
