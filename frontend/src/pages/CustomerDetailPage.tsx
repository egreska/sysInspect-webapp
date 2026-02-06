import { useQuery } from '@tanstack/react-query';
import { useParams, Link } from 'react-router-dom';
import { customersAPI } from '../services/api';
import { ArrowLeft, MapPin, Phone, FileText } from 'lucide-react';
import { format } from 'date-fns';

export default function CustomerDetailPage() {
  const { id } = useParams<{ id: string }>();
  
  const { data: customer, isLoading: loadingCustomer } = useQuery({
    queryKey: ['customer', id],
    queryFn: () => customersAPI.getById(id!),
    enabled: !!id,
  });

  const { data: inspectionsData, isLoading: loadingInspections } = useQuery({
    queryKey: ['customer-inspections', id],
    queryFn: () => customersAPI.getInspections(id!),
    enabled: !!id,
  });
  // Ensure we always have an array (handles wrong routing / API returning HTML)
  const inspections = Array.isArray(inspectionsData) ? inspectionsData : [];

  if (loadingCustomer) {
    return <div className="text-center py-12">Loading customer...</div>;
  }

  if (!customer) {
    return <div className="text-center py-12">Customer not found</div>;
  }

  return (
    <div className="space-y-6">
      <Link
        to="/customers"
        className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
      >
        <ArrowLeft className="w-4 h-4 mr-1" />
        Back to Customers
      </Link>

      {/* Customer Info */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">{customer.name}</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {customer.contactName && (
            <div>
              <p className="text-sm text-gray-600">Contact Person</p>
              <p className="text-gray-900 font-medium">{customer.contactName}</p>
            </div>
          )}
          
          {customer.phone && (
            <div className="flex items-center">
              <Phone className="w-4 h-4 text-gray-400 mr-2" />
              <div>
                <p className="text-sm text-gray-600">Phone</p>
                <p className="text-gray-900">{customer.phone}</p>
              </div>
            </div>
          )}
          
          {(customer.address || customer.city || customer.state || customer.zipCode) && (
            <div className="flex items-start">
              <MapPin className="w-4 h-4 text-gray-400 mr-2 mt-0.5" />
              <div>
                <p className="text-sm text-gray-600">Address</p>
                <p className="text-gray-900">
                  {[
                    customer.address,
                    [customer.city, customer.state, customer.zipCode].filter(Boolean).join(' ')
                  ].filter(Boolean).join(', ')}
                </p>
              </div>
            </div>
          )}
          
          {customer.site && (
            <div>
              <p className="text-sm text-gray-600">Site</p>
              <p className="text-gray-900">{customer.site}</p>
            </div>
          )}
        </div>
      </div>

      {/* Inspections */}
      <div className="bg-white rounded-lg shadow">
        <div className="p-6 border-b">
          <h3 className="text-lg font-semibold text-gray-900">
            Inspections ({inspections.length})
          </h3>
        </div>
        
        {loadingInspections ? (
          <div className="p-6 text-center text-gray-500">Loading inspections...</div>
        ) : inspections.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <FileText className="w-12 h-12 mx-auto text-gray-400 mb-4" />
            <p>No inspections found for this customer</p>
          </div>
        ) : (
          <div className="divide-y">
            {inspections.map((inspection) => (
              <Link
                key={inspection.id}
                to={`/inspections/${inspection.id}`}
                className="block p-6 hover:bg-gray-50 transition-colors"
              >
                <div className="flex justify-between items-center">
                  <div>
                    <h4 className="font-medium text-gray-900">
                      Inspection {inspection.date && `- ${format(new Date(inspection.date), 'MMMM dd, yyyy')}`}
                    </h4>
                    {inspection.inspectorName && (
                      <p className="text-sm text-gray-600 mt-1">
                        Inspector: {inspection.inspectorName}
                      </p>
                    )}
                  </div>
                  <div className="text-sm text-gray-400">
                    View Report →
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
