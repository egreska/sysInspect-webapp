import type { Inspection } from '../types';
import { extractRecordName } from './cloudkit';

export type InspectionCloudKitRecord = {
  recordName: string;
  fields: Record<string, { value?: unknown } | undefined>;
};

export function decodeInspection(record: InspectionCloudKitRecord): Inspection {
  const fields = record.fields;
  return {
    id: record.recordName,
    date: fields.CD_date?.value as string | undefined,
    inspectorName: (fields.CD_inspectorName?.value as string) || '',
    customerId: extractRecordName(fields.CD_customer?.value),
    createdDate: fields.CD_date?.value as string | undefined,
  };
}
