import type { Customer } from '../types';

export type CustomerCloudKitRecord = {
  recordName: string;
  fields: Record<string, { value?: unknown } | undefined>;
};

const customerField = {
  name: 'CD_name',
  contactName: 'CD_contactName',
  phone: 'CD_phone',
  address: 'CD_address',
  city: 'CD_city',
  state: 'CD_state',
  zipCode: 'CD_zipCode',
  site: 'CD_site',
  createdDate: 'CD_createdDate',
} as const;

export const customerDesiredKeys = Object.values(customerField);

function fieldString(fields: CustomerCloudKitRecord['fields'], key: string): string {
  return (fields[key]?.value as string) || '';
}

export function decodeCustomer(record: CustomerCloudKitRecord): Customer {
  const fields = record.fields;
  return {
    id: record.recordName,
    name: fieldString(fields, customerField.name),
    contactName: fieldString(fields, customerField.contactName),
    phone: fieldString(fields, customerField.phone),
    address: fieldString(fields, customerField.address),
    city: fieldString(fields, customerField.city),
    state: fieldString(fields, customerField.state),
    zipCode: fieldString(fields, customerField.zipCode),
    site: fieldString(fields, customerField.site),
    createdDate: fieldString(fields, customerField.createdDate),
  };
}
