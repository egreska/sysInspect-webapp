import type { Customer, Inspection, InspectionItem } from '../types';

export type LoadAdapter = {
  customers(): Promise<Customer[]>;
  customer(id: string): Promise<Customer | null>;
  inspections(): Promise<Inspection[]>;
  inspection(id: string): Promise<Inspection | null>;
  items(): Promise<InspectionItem[]>;
};

function dateMs(value: string | undefined): number {
  if (!value) return 0;
  const ms = new Date(value).getTime();
  return Number.isNaN(ms) ? 0 : ms;
}

function sortCustomersByName(customers: Customer[]): Customer[] {
  return [...customers].sort((a, b) => a.name.localeCompare(b.name));
}

function sortInspectionsByDateDesc(inspections: Inspection[]): Inspection[] {
  return [...inspections].sort((a, b) => dateMs(b.date) - dateMs(a.date));
}

export function createLoad(adapter: LoadAdapter) {
  return {
    async listCustomers(): Promise<Customer[]> {
      return sortCustomersByName(await adapter.customers());
    },

    async customerById(id: string): Promise<Customer> {
      const customer = await adapter.customer(id);
      if (!customer) throw new Error('Customer not found');
      return customer;
    },

    async listInspections(): Promise<Inspection[]> {
      return sortInspectionsByDateDesc(await adapter.inspections());
    },

    async inspectionsForCustomer(customerId: string): Promise<Inspection[]> {
      const inspections = await adapter.inspections();
      return sortInspectionsByDateDesc(
        inspections.filter((inspection) => inspection.customerId === customerId)
      );
    },

    async inspectionById(id: string): Promise<Inspection> {
      const inspection = await adapter.inspection(id);
      if (!inspection) throw new Error('Inspection not found');
      const items = (await adapter.items())
        .filter((row) => row.inspectionId === id)
        .sort((a, b) => a.sequenceNumber - b.sequenceNumber);
      const customer = inspection.customerId
        ? (await adapter.customer(inspection.customerId)) ?? undefined
        : undefined;
      return { ...inspection, customer, items };
    },
  };
}
