import { useQuery } from '@tanstack/react-query';
import { customersAPI } from '../services/api';
import { Link } from 'react-router-dom';
import { Search, MapPin, Phone } from 'lucide-react';
import { useState } from 'react';

export default function CustomersPage() {
  const [searchTerm, setSearchTerm] = useState('');
  const { data, isLoading } = useQuery({
    queryKey: ['customers'],
    queryFn: customersAPI.getAll,
  });

  // Ensure we always have an array (handles wrong routing / API returning HTML)
  const customers = Array.isArray(data) ? data : [];
  const filteredCustomers = customers.filter((customer) =>
    customer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.contactName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.city?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (isLoading) {
    return <div className="text-center py-12">Loading customers...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Customers</h2>
          <p className="mt-2 text-gray-600">{customers.length} total customers</p>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
        <input
          type="text"
          placeholder="Search customers..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
      </div>

      {/* Customer List */}
      <div className="bg-white rounded-lg shadow">
        <div className="divide-y">
          {filteredCustomers.length === 0 ? (
            <div className="p-12 text-center text-gray-500">
              No customers found
            </div>
          ) : (
            filteredCustomers.map((customer) => (
              <Link
                key={customer.id}
                to={`/customers/${customer.id}`}
                className="block p-6 hover:bg-gray-50 transition-colors"
              >
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-gray-900">
                      {customer.name}
                    </h3>
                    {customer.contactName && (
                      <p className="text-sm text-gray-600 mt-1">
                        Contact: {customer.contactName}
                      </p>
                    )}
                    <div className="flex items-center space-x-4 mt-2">
                      {(customer.city || customer.state) && (
                        <div className="flex items-center text-sm text-gray-500">
                          <MapPin className="w-4 h-4 mr-1" />
                          {[customer.city, customer.state].filter(Boolean).join(', ')}
                        </div>
                      )}
                      {customer.phone && (
                        <div className="flex items-center text-sm text-gray-500">
                          <Phone className="w-4 h-4 mr-1" />
                          {customer.phone}
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="text-sm text-gray-400">
                    →
                  </div>
                </div>
              </Link>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
