/**
 * Bootstrap: wait for CloudKit JS to load, configure, then render app.
 */
import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import App from './App';
import './index.css';
import { initCloudKit } from './services/cloudkit';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
});

function renderApp() {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </React.StrictMode>
  );
}

function bootstrap() {
  initCloudKit()
    .then(() => {
      renderApp();
    })
    .catch((err) => {
      console.error('CloudKit init failed:', err);
      // Still render app so user sees login - CloudKit errors will surface there
      renderApp();
    });
}

// Wait for CloudKit script to load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootstrap);
} else {
  bootstrap();
}
