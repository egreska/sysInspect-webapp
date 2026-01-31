import { useQuery } from '@tanstack/react-query';
import { customersAPI } from '../services/api';
import { BarChart, Users, FileText, TrendingUp } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function DashboardPage() {
  const { data: customers = [], isLoading } = useQuery({
    queryKey: ['customers'],
    queryFn: customersAPI.getAll,
  });

  if (isLoading) {
    return <div className="text-center py-12">Loading...</div>;
  }

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold text-gray-900">Dashboard</h2>
        <p className="mt-2 text-gray-600">Welcome to Systems Inspector Web</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="flex-shrink-0">
              <Users className="h-8 w-8 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Total Customers</p>
              <p className="text-2xl font-bold text-gray-900">{customers.length}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="flex-shrink-0">
              <FileText className="h-8 w-8 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Total Inspections</p>
              <p className="text-2xl font-bold text-gray-900">-</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="flex-shrink-0">
              <TrendingUp className="h-8 w-8 text-purple-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">This Month</p>
              <p className="text-2xl font-bold text-gray-900">-</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center">
            <div className="flex-shrink-0">
              <BarChart className="h-8 w-8 text-orange-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Reports Generated</p>
              <p className="text-2xl font-bold text-gray-900">-</p>
            </div>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Link
            to="/customers"
            className="p-4 border-2 border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-colors"
          >
            <Users className="h-6 w-6 text-blue-600 mb-2" />
            <h4 className="font-medium text-gray-900">View Customers</h4>
            <p className="text-sm text-gray-600 mt-1">Browse all customers</p>
          </Link>
          
          <div className="p-4 border-2 border-gray-200 rounded-lg opacity-50 cursor-not-allowed">
            <FileText className="h-6 w-6 text-gray-400 mb-2" />
            <h4 className="font-medium text-gray-900">Recent Inspections</h4>
            <p className="text-sm text-gray-600 mt-1">View recent work</p>
          </div>
          
          <div className="p-4 border-2 border-gray-200 rounded-lg opacity-50 cursor-not-allowed">
            <BarChart className="h-6 w-6 text-gray-400 mb-2" />
            <h4 className="font-medium text-gray-900">Reports</h4>
            <p className="text-sm text-gray-600 mt-1">Generate reports</p>
          </div>
        </div>
      </div>

      {/* Recent Customers */}
      <div className="bg-white rounded-lg shadow">
        <div className="p-6 border-b">
          <h3 className="text-lg font-semibold text-gray-900">Recent Customers</h3>
        </div>
        <div className="divide-y">
          {customers.slice(0, 5).map((customer) => (
            <Link
              key={customer.id}
              to={`/customers/${customer.id}`}
              className="block p-6 hover:bg-gray-50 transition-colors"
            >
              <div className="flex justify-between items-center">
                <div>
                  <h4 className="font-medium text-gray-900">{customer.name}</h4>
                  <p className="text-sm text-gray-600 mt-1">
                    {[customer.city, customer.state].filter(Boolean).join(', ')}
                  </p>
                </div>
                <div className="text-sm text-gray-500">
                  {customer.phone}
                </div>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
