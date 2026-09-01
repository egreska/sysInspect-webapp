import { useQuery } from '@tanstack/react-query';
import { useParams, Link } from 'react-router-dom';
import { load } from '../services/appLoad';
import { ArrowLeft, FileText, AlertCircle, Eye } from 'lucide-react';
import { format } from 'date-fns';
import { Issue } from '../issue';

export default function InspectionDetailPage() {
  const { id } = useParams<{ id: string }>();

  const { data: inspection, isLoading } = useQuery({
    queryKey: ['inspection', id],
    queryFn: () => load.inspectionById(id!),
    enabled: !!id,
  });

  if (isLoading) {
    return <div className="text-center py-12">Loading inspection...</div>;
  }

  if (!inspection) {
    return <div className="text-center py-12">Inspection not found</div>;
  }

  const needsImmediateCount =
    inspection.items?.filter(i => i.importance === 'Needs immediate attention').length || 0;
  const monitorCount = inspection.items?.filter(i => i.importance === 'Monitor').length || 0;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-start">
        <Link
          to={inspection.customer ? `/customers/${inspection.customer.id}` : '/'}
          className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
        >
          <ArrowLeft className="w-4 h-4 mr-1" />
          Back to Customer
        </Link>
        
        <Link
          to={`/inspections/${id}/report`}
          className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          <FileText className="w-4 h-4 mr-2" />
          Preview Report
        </Link>
      </div>

      {/* Inspection Header */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Inspection Report</h2>
        {inspection.date && (
          <p className="text-gray-600">
            Date: {format(new Date(inspection.date), 'MMMM dd, yyyy')}
          </p>
        )}
        {inspection.inspectorName && (
          <p className="text-gray-600">Inspector: {inspection.inspectorName}</p>
        )}
      </div>

      {/* Customer Info */}
      {inspection.customer && (
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Customer Information</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-600">Company</p>
              <p className="text-gray-900 font-medium">{inspection.customer.name}</p>
            </div>
            {inspection.customer.contactName && (
              <div>
                <p className="text-sm text-gray-600">Contact</p>
                <p className="text-gray-900">{inspection.customer.contactName}</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Summary */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <div className="flex items-center">
            <AlertCircle className="h-8 w-8 text-red-600 mr-3" />
            <div>
              <p className="text-sm text-red-600 font-medium">Needs immediate attention</p>
              <p className="text-2xl font-bold text-red-900">{needsImmediateCount}</p>
            </div>
          </div>
        </div>

        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
          <div className="flex items-center">
            <Eye className="h-8 w-8 text-blue-600 mr-3" />
            <div>
              <p className="text-sm text-blue-600 font-medium">Monitor</p>
              <p className="text-2xl font-bold text-blue-900">{monitorCount}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Inspection Items */}
      <div className="bg-white rounded-lg shadow">
        <div className="p-6 border-b">
          <h3 className="text-lg font-semibold text-gray-900">
            Inspection Items ({inspection.items?.length || 0})
          </h3>
        </div>

        <div className="divide-y">
          {inspection.items && inspection.items.length > 0 ? (
            inspection.items.map((item, index) => (
              <div key={item.id} className="p-6">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <h4 className="text-lg font-medium text-gray-900">
                      Item {index + 1}: {item.location}
                    </h4>
                    {item.bayNumber && (
                      <p className="text-sm text-gray-600">Bay Number: {item.bayNumber}</p>
                    )}
                  </div>
                  <span
                    className={`px-3 py-1 rounded-full text-sm font-medium ${
                      item.importance === 'Needs immediate attention'
                        ? 'bg-red-100 text-red-800'
                        : 'bg-blue-100 text-blue-800'
                    }`}
                  >
                    {item.importance}
                  </span>
                </div>

                {item.comments && (
                  <p className="text-gray-700 mb-4 italic">{item.comments}</p>
                )}

                {item.photoUrls.length > 0 && (
                  <div className="flex flex-wrap gap-3">
                    {item.photoUrls.map((url, photoIndex) => (
                      <a key={url} href={url} target="_blank" rel="noreferrer">
                        <img
                          src={url}
                          alt={`Inspection ${item.location} photo ${photoIndex + 1}`}
                          className="max-w-md rounded-lg border"
                          crossOrigin="anonymous"
                        />
                      </a>
                    ))}
                    {item.photoUrls.length > 1 && (
                      <span className="self-end text-sm text-gray-500">{item.photoUrls.length} photos</span>
                    )}
                  </div>
                )}

                <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                  {Issue.labels(item.issues).map((label) => (
                    <div key={label} className="flex items-center text-gray-700">
                      {label}
                    </div>
                  ))}
                </div>
              </div>
            ))
          ) : (
            <div className="p-12 text-center text-gray-500">
              No inspection items
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
