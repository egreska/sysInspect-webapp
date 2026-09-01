import { useQuery } from '@tanstack/react-query';
import { useParams, Link } from 'react-router-dom';
import { load } from '../services/appLoad';
import { generatePDF } from '../services/pdfGenerator';
import { ArrowLeft, Download, RotateCcw } from 'lucide-react';
import { format } from 'date-fns';
import { useState, useEffect, useCallback } from 'react';
import type { Inspection, InspectionItem } from '../types';
import { Issue } from '../issue';

export default function ReportPreviewPage() {
  const { id } = useParams<{ id: string }>();
  const [downloading, setDownloading] = useState(false);
  const [edited, setEdited] = useState<Inspection | null>(null);

  const { data: inspection, isLoading } = useQuery({
    queryKey: ['inspection', id],
    queryFn: () => load.inspectionById(id!),
    enabled: !!id,
  });

  useEffect(() => {
    if (inspection && !edited) {
      setEdited(structuredClone(inspection));
    }
  }, [inspection, edited]);

  const resetEdits = useCallback(() => {
    if (inspection) setEdited(structuredClone(inspection));
  }, [inspection]);

  const updateItem = useCallback(
    (index: number, field: keyof InspectionItem, value: string) => {
      setEdited((prev) => {
        if (!prev?.items) return prev;
        const next = { ...prev, items: [...prev.items] };
        next.items[index] = { ...next.items[index], [field]: value };
        return next;
      });
    },
    []
  );

  const handleDownloadPDF = async () => {
    if (!edited) return;
    setDownloading(true);
    try {
      const blob = await generatePDF(edited);
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      const baseName = (edited.customer?.name || 'report').replace(/[/\\?%*:|"<>]/g, '-');
      link.href = url;
      link.download = `inspection-${baseName}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch {
      alert('Failed to generate PDF');
    } finally {
      setDownloading(false);
    }
  };

  if (isLoading) {
    return <div className="text-center py-12">Loading report preview...</div>;
  }

  if (!inspection || !edited) {
    return <div className="text-center py-12">Inspection not found</div>;
  }

  const items = edited.items || [];

  return (
    <div className="space-y-6">
      {/* Top Bar */}
      <div className="flex flex-wrap justify-between items-center gap-3">
        <Link
          to={`/inspections/${id}`}
          className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
        >
          <ArrowLeft className="w-4 h-4 mr-1" />
          Back to Inspection
        </Link>

        <div className="flex items-center gap-3">
          <button
            onClick={resetEdits}
            className="inline-flex items-center px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <RotateCcw className="w-4 h-4 mr-2" />
            Reset Changes
          </button>

          <button
            onClick={handleDownloadPDF}
            disabled={downloading}
            className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            <Download className="w-4 h-4 mr-2" />
            {downloading ? 'Generating...' : 'Download PDF'}
          </button>
        </div>
      </div>

      {/* Inspection Header (read-only) */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-1">Report Preview</h2>
        <p className="text-sm text-gray-500 mb-4">
          Edit text fields below before downloading. Changes are temporary and will not be saved.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm text-gray-700">
          {edited.date && (
            <p>
              <span className="font-medium text-gray-900">Date:</span>{' '}
              {format(new Date(edited.date), 'MMMM dd, yyyy')}
            </p>
          )}
          {edited.inspectorName && (
            <p>
              <span className="font-medium text-gray-900">Inspector:</span>{' '}
              {edited.inspectorName}
            </p>
          )}
          {edited.customer?.name && (
            <p>
              <span className="font-medium text-gray-900">Customer:</span>{' '}
              {edited.customer.name}
            </p>
          )}
          {edited.customer?.contactName && (
            <p>
              <span className="font-medium text-gray-900">Contact:</span>{' '}
              {edited.customer.contactName}
            </p>
          )}
        </div>
      </div>

      {/* Editable Items */}
      <div className="bg-white rounded-lg shadow">
        <div className="p-6 border-b">
          <h3 className="text-lg font-semibold text-gray-900">
            Inspection Items ({items.length})
          </h3>
        </div>

        <div className="divide-y">
          {items.length > 0 ? (
            items.map((item, index) => {
              const issueLabels = Issue.labels(item.issues);
              return (
                <div key={item.id} className="p-6">
                  <div className="flex flex-col md:flex-row gap-6">
                    {/* Photo thumbnail (read-only) */}
                    <div className="flex-shrink-0 w-full md:w-48">
                      {item.photoUrls[0] ? (
                        <div className="relative">
                          <img
                            src={item.photoUrls[0]}
                            alt={`Item ${index + 1}`}
                            className="w-full h-36 object-cover rounded-lg border"
                            crossOrigin="anonymous"
                          />
                          {item.photoUrls.length > 1 && (
                            <span className="absolute bottom-2 right-2 rounded-full bg-black/70 px-2 py-0.5 text-xs text-white">
                              {item.photoUrls.length}
                            </span>
                          )}
                          {item.photoUrls.length > 1 && (
                            <div className="mt-2 flex gap-1 overflow-x-auto">
                              {item.photoUrls.slice(1).map((url) => (
                                <img
                                  key={url}
                                  src={url}
                                  alt=""
                                  className="h-12 w-12 object-cover rounded border"
                                  crossOrigin="anonymous"
                                />
                              ))}
                            </div>
                          )}
                        </div>
                      ) : (
                        <div className="w-full h-36 bg-gray-100 rounded-lg border flex items-center justify-center text-sm text-gray-400">
                          No Photo
                        </div>
                      )}
                    </div>

                    {/* Editable fields */}
                    <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          Location
                        </label>
                        <input
                          type="text"
                          value={item.location || ''}
                          onChange={(e) => updateItem(index, 'location', e.target.value)}
                          className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        />
                      </div>

                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          Bay Number
                        </label>
                        <input
                          type="text"
                          value={item.bayNumber || ''}
                          onChange={(e) => updateItem(index, 'bayNumber', e.target.value)}
                          className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        />
                      </div>

                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          Importance
                        </label>
                        <select
                          value={item.importance}
                          onChange={(e) => updateItem(index, 'importance', e.target.value)}
                          className={`w-full rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm font-medium ${
                            item.importance === 'Needs immediate attention'
                              ? 'border-red-300 text-red-800 bg-red-50'
                              : 'border-blue-300 text-blue-800 bg-blue-50'
                          }`}
                        >
                          <option value="Needs immediate attention">Needs immediate attention</option>
                          <option value="Monitor">Monitor</option>
                        </select>
                      </div>

                      <div className="sm:col-span-2">
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          Comments
                        </label>
                        <textarea
                          rows={3}
                          value={item.comments || ''}
                          onChange={(e) => updateItem(index, 'comments', e.target.value)}
                          className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                        />
                      </div>
                    </div>
                  </div>

                  {/* Damage list (read-only reference) */}
                  {issueLabels.length > 0 && (
                    <div className="mt-4 pt-3 border-t border-gray-100">
                      <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
                        Issues
                      </p>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-1 text-sm">
                        {issueLabels.map((label) => (
                          <div key={label} className="flex items-center text-gray-600">
                            {label}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              );
            })
          ) : (
            <div className="p-12 text-center text-gray-500">No inspection items</div>
          )}
        </div>
      </div>

      {/* Bottom download bar (convenience for long lists) */}
      {items.length > 3 && (
        <div className="flex justify-end">
          <button
            onClick={handleDownloadPDF}
            disabled={downloading}
            className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            <Download className="w-4 h-4 mr-2" />
            {downloading ? 'Generating...' : 'Download PDF'}
          </button>
        </div>
      )}
    </div>
  );
}
