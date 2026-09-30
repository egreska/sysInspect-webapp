import { useEffect, type ReactNode } from 'react';
import { Link } from 'react-router-dom';

export default function PublicDocument({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  useEffect(() => {
    document.title = `${title} — Pallet Rack Safety`;
  }, [title]);

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <main className="max-w-2xl mx-auto px-6 py-12">
        <p className="text-sm text-gray-500">Pallet Rack Safety</p>
        <h1 className="text-3xl font-bold mt-2 mb-8">{title}</h1>
        <div className="space-y-6 leading-relaxed">{children}</div>
        <nav className="mt-12 pt-6 border-t border-gray-200 flex gap-6 text-sm">
          <Link className="text-blue-700 underline" to="/support">
            Support
          </Link>
          <Link className="text-blue-700 underline" to="/privacy">
            Privacy Policy
          </Link>
        </nav>
      </main>
    </div>
  );
}
