import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

function CloudKitButtonContainer() {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const signIn = document.getElementById('apple-sign-in-button');
    const signOut = document.getElementById('apple-sign-out-button');
    if (signIn && containerRef.current) {
      // Move button into the login card so it's visible (it's in body by default, below the fold)
      if (signIn.parentElement !== containerRef.current) {
        containerRef.current.appendChild(signIn);
      }
      signIn.style.display = 'flex';
      signIn.style.justifyContent = 'center';
      signIn.style.width = '100%';
    }
    if (signOut) signOut.style.display = 'none';
    return () => {
      if (signIn) {
        signIn.style.display = 'none';
        document.body.appendChild(signIn);
      }
    };
  }, []);
  return <div ref={containerRef} className="min-h-[44px] w-full" />;
}

export default function LoginPage() {
  const { isAuthenticated, isLoading, error, cloudKitReady, checkAuthAfterPopup } = useAuthStore();
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  // Workaround: Apple Sign-in popup may close without resolving whenUserSignsIn promise.
  // Re-check auth when window regains focus (popup closed).
  useEffect(() => {
    const onFocus = () => {
      if (cloudKitReady && !isAuthenticated && !isLoading) {
        checkAuthAfterPopup();
      }
    };
    window.addEventListener('focus', onFocus);
    return () => window.removeEventListener('focus', onFocus);
  }, [cloudKitReady, isAuthenticated, isLoading, checkAuthAfterPopup]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 px-4">
      <div className="max-w-md w-full">
        <div className="bg-white rounded-lg shadow-xl p-8">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-gray-900">Systems Inspector</h1>
            <p className="text-gray-600 mt-2">Sign in to access your inspections</p>
          </div>

          {!cloudKitReady || isLoading ? (
            <div className="text-center py-8 text-gray-500">Loading...</div>
          ) : error ? (
            <div className="space-y-4">
              <div className="bg-amber-50 border border-amber-200 text-amber-800 px-4 py-3 rounded-lg">
                <p className="font-medium">CloudKit not configured</p>
                <p className="text-sm mt-1">{error}</p>
                <p className="text-sm mt-2">
                  Set <code className="text-xs bg-amber-100 px-1 rounded">VITE_CLOUDKIT_CONTAINER_ID</code>,{' '}
                  <code className="text-xs bg-amber-100 px-1 rounded">VITE_CLOUDKIT_API_TOKEN</code>, and{' '}
                  <code className="text-xs bg-amber-100 px-1 rounded">VITE_CLOUDKIT_ENVIRONMENT</code> as
                  runtime variables (Docker) or in <code className="text-xs">frontend/.env</code> for local dev.
                  API token: CloudKit Dashboard → API Access → API Tokens.
                </p>
              </div>
            </div>
          ) : (
            <div className="space-y-6 flex flex-col items-center justify-center">
              {/* CloudKit appends Sign in with Apple button to apple-sign-in-button; we move it here */}
              <CloudKitButtonContainer />
            </div>
          )}

          <div className="mt-6 text-center text-sm text-gray-600">
            <p>Sign in with the same Apple ID used in the iOS app</p>
          </div>
        </div>
      </div>
    </div>
  );
}
