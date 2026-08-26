/**
 * CloudKit JS-based API - replaces backend for data access.
 * Uses Sign in with Apple for auth; fetches directly from CloudKit.
 */
import { logger } from '../utils/logger';
import type { Customer, Inspection } from '../types';
import {
  fetchRecord,
  fetchInspections,
  fetchInspectionItems,
  mapCustomerRecord,
  mapInspectionRecord,
  queryRecords,
  extractRecordName,
} from './cloudkit';
import { decodeInspectionItem } from './inspectionItemCodec';

/**
 * Fetch all customers. Private database is scoped to the signed-in iCloud user,
 * so we get only their data. Query all CD_Customer in the zone.
 */
export async function getCustomers(): Promise<Customer[]> {
  try {
    const records = await queryRecords('CD_Customer', [], { fieldName: 'CD_name', ascending: true });
    return records.map(mapCustomerRecord);
  } catch (err) {
    logger.error('CloudKit getCustomers failed', err);
    throw err;
  }
}

export async function getCustomerById(id: string): Promise<Customer | null> {
  const record = await fetchRecord(id, 'CD_Customer');
  if (!record) return null;
  return mapCustomerRecord(record);
}

export async function getInspectionsByCustomerId(customerId: string): Promise<Inspection[]> {
  try {
    const records = await fetchInspections(customerId);
    logger.debug(`[CloudKit] getInspectionsByCustomerId: ${records.length} inspections matched`);
    return records.map(mapInspectionRecord);
  } catch (err) {
    logger.error('CloudKit getInspectionsByCustomerId failed', err);
    throw err;
  }
}

export async function getInspectionById(id: string): Promise<Inspection | null> {
  const r = await fetchRecord(id, 'CD_Inspection');
  if (!r) return null;
  const customerId = extractRecordName(r.fields.CD_customer?.value);
  let customer: Customer | null = null;
  if (customerId) {
    customer = await getCustomerById(customerId);
  }

  const itemRecords = await fetchInspectionItems(id);
  const items = itemRecords.map(decodeInspectionItem);
  items.sort((a, b) => a.sequenceNumber - b.sequenceNumber);

  return {
    id: r.recordName,
    date: r.fields.CD_date?.value as string | undefined,
    inspectorName: (r.fields.CD_inspectorName?.value as string) || '',
    customerId,
    customer: customer || undefined,
    items,
    createdDate: r.fields.CD_date?.value as string | undefined,
  };
}
