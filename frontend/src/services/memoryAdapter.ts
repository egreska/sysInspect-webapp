import type { Customer, Inspection, InspectionItem } from '../types';
import type { LoadAdapter } from './load';

export function createMemoryAdapter(data: {
  customers?: Customer[];
  inspections?: Inspection[];
  items?: InspectionItem[];
}): LoadAdapter {
  const customers = data.customers ?? [];
  const inspections = data.inspections ?? [];
  const items = data.items ?? [];
  return {
    customers: async () => customers.slice(),
    customer: async (id) => customers.find((row) => row.id === id) ?? null,
    inspections: async () => inspections.slice(),
    inspection: async (id) => inspections.find((row) => row.id === id) ?? null,
    items: async () => items.slice(),
  };
}
