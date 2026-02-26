import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

function CloudKitButtonVisibility() {
  useEffect(() => {
    const signIn = document.getElementById('apple-sign-in-button');
    const signOut = document.getElementById('apple-sign-out-button');
    if (signIn) {
      signIn.style.display = 'flex';
      signIn.style.justifyContent = 'center';
      signIn.style.width = '100%';
    }
    if (signOut) signOut.style.display = 'none';
    return () => {
      if (signIn) signIn.style.display = 'none';
    };
  }, []);
  return null;
}

export default function LoginPage() {
  const { isAuthenticated, isLoading, error, cloudKitReady } = useAuthStore();
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

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
                  Set VITE_CLOUDKIT_CONTAINER_ID and VITE_CLOUDKIT_API_TOKEN in your environment.
                  Create an API token in CloudKit Dashboard → API Access → API Tokens.
                </p>
              </div>
            </div>
          ) : (
            <div className="space-y-6 min-h-[44px] flex flex-col items-center justify-center">
              {/* CloudKit Sign in button is in index.html - we show it via CloudKitButtonVisibility */}
              <CloudKitButtonVisibility />
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
