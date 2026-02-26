import { useQuery } from '@tanstack/react-query';
import { useParams, Link } from 'react-router-dom';
import { inspectionsAPI, reportsAPI } from '../services/api';
import { ArrowLeft, Download, AlertCircle, Wrench, Eye } from 'lucide-react';
import { format } from 'date-fns';
import { useState } from 'react';
import type { InspectionItem } from '../types';

export default function InspectionDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [downloading, setDownloading] = useState(false);

  const { data: inspection, isLoading } = useQuery({
    queryKey: ['inspection', id],
    queryFn: () => inspectionsAPI.getById(id!),
    enabled: !!id,
  });

  const handleDownloadPDF = async () => {
    if (!id) return;
    const baseName = (inspection?.customer?.name || 'report').replace(/[/\\?%*:|"<>]/g, '-');
    setDownloading(true);
    try {
      await reportsAPI.downloadPDF(id, `inspection-${baseName}.pdf`);
    } catch (error) {
      alert('Failed to download PDF');
    } finally {
      setDownloading(false);
    }
  };

  if (isLoading) {
    return <div className="text-center py-12">Loading inspection...</div>;
  }

  if (!inspection) {
    return <div className="text-center py-12">Inspection not found</div>;
  }

  const criticalCount = inspection.items?.filter(i => i.importance === 'Critical').length || 0;
  const repairCount = inspection.items?.filter(i => i.importance === 'Repair').length || 0;
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
        
        <button
          onClick={handleDownloadPDF}
          disabled={downloading}
          className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >
          <Download className="w-4 h-4 mr-2" />
          {downloading ? 'Generating...' : 'Download PDF'}
        </button>
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
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <div className="flex items-center">
            <AlertCircle className="h-8 w-8 text-red-600 mr-3" />
            <div>
              <p className="text-sm text-red-600 font-medium">Critical</p>
              <p className="text-2xl font-bold text-red-900">{criticalCount}</p>
            </div>
          </div>
        </div>

        <div className="bg-orange-50 border border-orange-200 rounded-lg p-6">
          <div className="flex items-center">
            <Wrench className="h-8 w-8 text-orange-600 mr-3" />
            <div>
              <p className="text-sm text-orange-600 font-medium">Repair Required</p>
              <p className="text-2xl font-bold text-orange-900">{repairCount}</p>
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
                      item.importance === 'Critical'
                        ? 'bg-red-100 text-red-800'
                        : item.importance === 'Repair'
                        ? 'bg-orange-100 text-orange-800'
                        : 'bg-blue-100 text-blue-800'
                    }`}
                  >
                    {item.importance}
                  </span>
                </div>

                {item.comments && (
                  <p className="text-gray-700 mb-4 italic">{item.comments}</p>
                )}

                {item.photoData && (
                  <img
                    src={`data:image/jpeg;base64,${item.photoData}`}
                    alt={`Inspection ${item.location}`}
                    className="max-w-md rounded-lg border"
                  />
                )}

                {/* Damage Details */}
                <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                  {getDamagesList(item).map((damage, i) => (
                    <div key={i} className="flex items-center text-gray-700">
                      <span className="text-red-500 mr-2">•</span>
                      {damage}
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

function getDamagesList(item: InspectionItem): string[] {
  const damages: string[] = [];
  
  if (item.uprightFrontDamage) damages.push('Upright Front Damage');
  if (item.uprightFrontTwisted) damages.push('Upright Front Twisted');
  if (item.uprightRearDamage) damages.push('Upright Rear Damage');
  if (item.uprightRearTwisted) damages.push('Upright Rear Twisted');
  if (item.uprightAlignmentOutOfAlignment) damages.push('Out of Alignment');
  if (item.uprightAlignmentOutOfVerticalPlumb) damages.push('Out of Vertical Plumb');
  if (item.beamFrontDamage) damages.push('Beam Front Damage');
  if (item.beamFrontBowed) damages.push('Beam Front Bowed');
  if (item.beamRearDamage) damages.push('Beam Rear Damage');
  if (item.beamRearBowed) damages.push('Beam Rear Bowed');
  if (item.bracingDamage) damages.push('Bracing Damage');
  if (item.basePlateDamaged) damages.push('Base Plate Damaged');
  if (item.basePlateTwisted) damages.push('Base Plate Twisted');
  if (item.basePlateFloorDamaged) damages.push('Floor Damaged');
  if (item.anchorsDamaged) damages.push('Anchors Damaged');
  if (item.anchorsMissing) damages.push('Anchors Missing');
  if (item.anchors && !item.anchorsTorqued) damages.push('Anchors Not Torqued');
  if (item.wireDeckDamaged) damages.push('Wire Deck Damaged');
  if (item.wireDeckMissing) damages.push('Wire Deck Missing');
  if (item.wireDeckOutOfPosition) damages.push('Wire Deck Out of Position');
  if (item.postProtectorDamaged) damages.push('Post Protector Damaged');
  if (item.postProtectorMissing) damages.push('Post Protector Missing');
  if (item.postProtectorRepairRequired) damages.push('Post Protector Repair Required');
  if (item.aisleGuardingDamaged) damages.push('Aisle Guarding Damaged');
  if (item.aisleGuardingMissing) damages.push('Aisle Guarding Missing');
  if (item.aisleGuardingRepairRequired) damages.push('Aisle Guarding Repair Required');
  
  return damages;
}
