import type { Inspection } from '../types';
import { extractRecordName } from './cloudkit';

export type InspectionCloudKitRecord = {
  recordName: string;
  fields: Record<string, { value?: unknown } | undefined>;
};

function decodeDate(raw: unknown): string | undefined {
  if (raw == null || raw === '') return undefined;
  if (typeof raw === 'number') {
    const d = new Date(raw);
    return Number.isNaN(d.getTime()) ? undefined : d.toISOString();
  }
  if (typeof raw === 'string') return raw;
  return undefined;
}

export function decodeInspection(record: InspectionCloudKitRecord): Inspection {
  const fields = record.fields;
  const date = decodeDate(fields.CD_date?.value);
  return {
    id: record.recordName,
    date,
    inspectorName: (fields.CD_inspectorName?.value as string) || '',
    customerId: extractRecordName(fields.CD_customer?.value),
    createdDate: date,
  };
}
