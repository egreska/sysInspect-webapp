import type { Customer, Inspection, InspectionItem } from '../types';
import type { LoadAdapter } from './load';

export function createMemoryAdapter(data: {
  customers?: Customer[];
  customersStoppedEarly?: boolean;
  inspections?: Inspection[];
  inspectionsStoppedEarly?: boolean;
  items?: InspectionItem[];
  itemsStoppedEarly?: boolean;
}): LoadAdapter {
  const customers = data.customers ?? [];
  const inspections = data.inspections ?? [];
  const items = data.items ?? [];
  return {
    customers: async () => ({ rows: customers.slice(), stoppedEarly: data.customersStoppedEarly === true }),
    customer: async (id) => customers.find((row) => row.id === id) ?? null,
    inspections: async () => ({
      rows: inspections.slice(),
      stoppedEarly: data.inspectionsStoppedEarly === true,
    }),
    inspection: async (id) => inspections.find((row) => row.id === id) ?? null,
    items: async (inspectionId) => ({
      rows: items.filter((row) => row.inspectionId === inspectionId),
      stoppedEarly: data.itemsStoppedEarly === true,
    }),
  };
}
