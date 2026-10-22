import type { Customer, Inspection, InspectionItem } from '../types';

export const LIST_STOPPED_EARLY = 'This list stopped early. CloudKit may have more records.';

export type Listed<T> = { rows: T[]; stoppedEarly: boolean };

export type LoadAdapter = {
  customers(): Promise<Listed<Customer>>;
  customer(id: string): Promise<Customer | null>;
  inspections(): Promise<Listed<Inspection>>;
  inspection(id: string): Promise<Inspection | null>;
  items(inspectionId: string): Promise<Listed<InspectionItem>>;
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
    async listCustomers(): Promise<Listed<Customer>> {
      const listed = await adapter.customers();
      return { rows: sortCustomersByName(listed.rows), stoppedEarly: listed.stoppedEarly };
    },

    async customerById(id: string): Promise<Customer> {
      const customer = await adapter.customer(id);
      if (!customer) throw new Error('Customer not found');
      return customer;
    },

    async listInspections(): Promise<Listed<Inspection>> {
      const listed = await adapter.inspections();
      return { rows: sortInspectionsByDateDesc(listed.rows), stoppedEarly: listed.stoppedEarly };
    },

    async inspectionsForCustomer(customerId: string): Promise<Listed<Inspection>> {
      const listed = await adapter.inspections();
      return {
        rows: sortInspectionsByDateDesc(
          listed.rows.filter((inspection) => inspection.customerId === customerId)
        ),
        stoppedEarly: listed.stoppedEarly,
      };
    },

    async inspectionById(id: string): Promise<Inspection> {
      const inspection = await adapter.inspection(id);
      if (!inspection) throw new Error('Inspection not found');
      const listed = await adapter.items(id);
      const items = listed.rows
        .filter((row) => row.inspectionId === id)
        .sort((a, b) => a.sequenceNumber - b.sequenceNumber);
      const customer = inspection.customerId
        ? (await adapter.customer(inspection.customerId)) ?? undefined
        : undefined;
      return { ...inspection, customer, items, itemsStoppedEarly: listed.stoppedEarly };
    },
  };
}
