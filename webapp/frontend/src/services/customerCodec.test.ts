import { describe, expect, it } from 'vitest';
import { decodeCustomer } from './customerCodec';

function record(
  fields: Record<string, unknown>,
  recordName = 'cust-1'
): { recordName: string; fields: Record<string, { value?: unknown }> } {
  const mapped: Record<string, { value?: unknown }> = {};
  for (const [key, value] of Object.entries(fields)) {
    mapped[key] = { value };
  }
  return { recordName, fields: mapped };
}

describe('decodeCustomer', () => {
  it('decodes name and address fields', () => {
    const customer = decodeCustomer(
      record({
        CD_name: 'Acme Storage',
        CD_contactName: 'Pat Lee',
        CD_phone: '555-0100',
        CD_address: '1 Dock St',
        CD_city: 'Austin',
        CD_state: 'TX',
        CD_zipCode: '78701',
        CD_site: 'Warehouse A',
        CD_createdDate: '2026-01-15',
      })
    );
    expect(customer).toEqual({
      id: 'cust-1',
      name: 'Acme Storage',
      contactName: 'Pat Lee',
      phone: '555-0100',
      address: '1 Dock St',
      city: 'Austin',
      state: 'TX',
      zipCode: '78701',
      site: 'Warehouse A',
      createdDate: '2026-01-15',
    });
  });

  it('defaults missing strings to empty', () => {
    const customer = decodeCustomer(record({}));
    expect(customer.id).toBe('cust-1');
    expect(customer.name).toBe('');
    expect(customer.contactName).toBe('');
    expect(customer.site).toBe('');
    expect(customer.createdDate).toBe('');
  });
});
