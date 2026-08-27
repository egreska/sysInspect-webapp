import { describe, expect, it } from 'vitest';
import { decodeInspection } from './inspectionCodec';

function record(
  fields: Record<string, unknown>,
  recordName = 'insp-1'
): { recordName: string; fields: Record<string, { value?: unknown }> } {
  const mapped: Record<string, { value?: unknown }> = {};
  for (const [key, value] of Object.entries(fields)) {
    mapped[key] = { value };
  }
  return { recordName, fields: mapped };
}

describe('decodeInspection', () => {
  it('decodes scalars and a string customer reference', () => {
    const inspection = decodeInspection(
      record({
        CD_date: '2026-08-01T12:00:00Z',
        CD_inspectorName: 'Jordan',
        CD_customer: 'cust-1',
      })
    );
    expect(inspection.id).toBe('insp-1');
    expect(inspection.date).toBe('2026-08-01T12:00:00Z');
    expect(inspection.inspectorName).toBe('Jordan');
    expect(inspection.customerId).toBe('cust-1');
    expect(inspection.createdDate).toBe('2026-08-01T12:00:00Z');
    expect(inspection.items).toBeUndefined();
    expect(inspection.customer).toBeUndefined();
  });

  it('decodes a recordName object customer reference', () => {
    const inspection = decodeInspection(
      record({
        CD_customer: { recordName: 'cust-9' },
      })
    );
    expect(inspection.customerId).toBe('cust-9');
  });

  it('omits customerId when the reference is missing', () => {
    const inspection = decodeInspection(record({ CD_inspectorName: 'Alex' }));
    expect(inspection.inspectorName).toBe('Alex');
    expect(inspection.customerId).toBeUndefined();
  });
});
