import type { Inspection } from '../types';
import { extractRecordName } from './recordName';

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

const inspectionField = {
  date: 'CD_date',
  inspectorName: 'CD_inspectorName',
  customer: 'CD_customer',
} as const;

export const inspectionDesiredKeys = Object.values(inspectionField);

export function decodeInspection(record: InspectionCloudKitRecord): Inspection {
  const fields = record.fields;
  const date = decodeDate(fields[inspectionField.date]?.value);
  return {
    id: record.recordName,
    date,
    inspectorName: (fields[inspectionField.inspectorName]?.value as string) || '',
    customerId: extractRecordName(fields[inspectionField.customer]?.value),
    createdDate: date,
  };
}
