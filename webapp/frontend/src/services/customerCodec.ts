import type { Customer } from '../types';

export type CustomerCloudKitRecord = {
  recordName: string;
  fields: Record<string, { value?: unknown } | undefined>;
};

function fieldString(fields: CustomerCloudKitRecord['fields'], key: string): string {
  return (fields[key]?.value as string) || '';
}

export function decodeCustomer(record: CustomerCloudKitRecord): Customer {
  const fields = record.fields;
  return {
    id: record.recordName,
    name: fieldString(fields, 'CD_name'),
    contactName: fieldString(fields, 'CD_contactName'),
    phone: fieldString(fields, 'CD_phone'),
    address: fieldString(fields, 'CD_address'),
    city: fieldString(fields, 'CD_city'),
    state: fieldString(fields, 'CD_state'),
    zipCode: fieldString(fields, 'CD_zipCode'),
    site: fieldString(fields, 'CD_site'),
    createdDate: fieldString(fields, 'CD_createdDate'),
  };
}
