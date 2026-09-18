import { describe, expect, it } from 'vitest';
import type { InspectionItem } from '../types';
import { createLoad } from './load';
import { createMemoryAdapter } from './memoryAdapter';

function item(
  over: Partial<InspectionItem> & Pick<InspectionItem, 'id' | 'inspectionId'>
): InspectionItem {
  return {
    location: '',
    sequenceNumber: 0,
    photoUrls: [],
    issues: [],
    importance: 'Monitor',
    ...over,
  };
}

describe('createLoad', () => {
  it('throws when customerById is missing', async () => {
    const load = createLoad(createMemoryAdapter({}));
    await expect(load.customerById('missing')).rejects.toThrow('Customer not found');
  });

  it('returns the customer when present', async () => {
    const load = createLoad(
      createMemoryAdapter({ customers: [{ id: 'c1', name: 'Acme' }] })
    );
    await expect(load.customerById('c1')).resolves.toEqual({ id: 'c1', name: 'Acme' });
  });

  it('sorts listCustomers by name', async () => {
    const load = createLoad(
      createMemoryAdapter({
        customers: [
          { id: '2', name: 'Zed' },
          { id: '1', name: 'Acme' },
        ],
      })
    );
    const names = (await load.listCustomers()).map((c) => c.name);
    expect(names).toEqual(['Acme', 'Zed']);
  });

  it('returns an empty list when there are no customers', async () => {
    const load = createLoad(createMemoryAdapter({}));
    await expect(load.listCustomers()).resolves.toEqual([]);
  });

  it('throws when inspectionById is missing', async () => {
    const load = createLoad(createMemoryAdapter({}));
    await expect(load.inspectionById('missing')).rejects.toThrow('Inspection not found');
  });

  it('attaches customer and items sorted by sequenceNumber', async () => {
    const load = createLoad(
      createMemoryAdapter({
        customers: [{ id: 'c1', name: 'Acme' }],
        inspections: [
          { id: 'i1', customerId: 'c1', inspectorName: 'Pat', date: '2026-01-02' },
        ],
        items: [
          item({ id: 'b', inspectionId: 'i1', sequenceNumber: 2, location: 'B' }),
          item({ id: 'a', inspectionId: 'i1', sequenceNumber: 1, location: 'A' }),
          item({ id: 'other', inspectionId: 'i9', sequenceNumber: 1, location: 'X' }),
        ],
      })
    );
    const inspection = await load.inspectionById('i1');
    expect(inspection.customer).toEqual({ id: 'c1', name: 'Acme' });
    expect(inspection.items?.map((row) => row.id)).toEqual(['a', 'b']);
  });

  it('omits customer when the referenced customer is missing', async () => {
    const load = createLoad(
      createMemoryAdapter({
        inspections: [{ id: 'i1', customerId: 'gone' }],
      })
    );
    const inspection = await load.inspectionById('i1');
    expect(inspection.customer).toBeUndefined();
    expect(inspection.items).toEqual([]);
  });

  it('listInspections does not attach customer or items', async () => {
    const load = createLoad(
      createMemoryAdapter({
        customers: [{ id: 'c1', name: 'Acme' }],
        inspections: [{ id: 'i1', customerId: 'c1', date: '2026-01-01' }],
        items: [item({ id: 'a', inspectionId: 'i1' })],
      })
    );
    const [inspection] = await load.listInspections();
    expect(inspection.customer).toBeUndefined();
    expect(inspection.items).toBeUndefined();
  });

  it('sorts listInspections by date descending', async () => {
    const load = createLoad(
      createMemoryAdapter({
        inspections: [
          { id: 'old', date: '2026-01-01' },
          { id: 'new', date: '2026-06-01' },
        ],
      })
    );
    expect((await load.listInspections()).map((row) => row.id)).toEqual(['new', 'old']);
  });

  it('filters inspectionsForCustomer and sorts by date descending', async () => {
    const load = createLoad(
      createMemoryAdapter({
        inspections: [
          { id: 'a-old', customerId: 'c1', date: '2026-01-01' },
          { id: 'other', customerId: 'c2', date: '2026-08-01' },
          { id: 'a-new', customerId: 'c1', date: '2026-06-01' },
        ],
      })
    );
    expect((await load.inspectionsForCustomer('c1')).map((row) => row.id)).toEqual([
      'a-new',
      'a-old',
    ]);
  });

  it('returns an empty list when a customer has no inspections', async () => {
    const load = createLoad(
      createMemoryAdapter({
        inspections: [{ id: 'i1', customerId: 'c2' }],
      })
    );
    await expect(load.inspectionsForCustomer('c1')).resolves.toEqual([]);
  });
});
