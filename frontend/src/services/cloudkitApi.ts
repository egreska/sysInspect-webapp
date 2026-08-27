/**
 * Domain CloudKit queries. Pages talk to this module (via api.ts), not queryRecords.
 */
import { logger } from '../utils/logger';
import type { Customer, Inspection } from '../types';
import {
  fetchRecord,
  queryRecords,
  extractRecordName,
} from './cloudkit';
import { decodeCustomer } from './customerCodec';
import { decodeInspection } from './inspectionCodec';
import { decodeInspectionItem } from './inspectionItemCodec';

function dateMs(value: string | undefined): number {
  if (!value) return 0;
  const ms = new Date(value).getTime();
  return Number.isNaN(ms) ? 0 : ms;
}

function sortInspectionsByDateDesc(inspections: Inspection[]): Inspection[] {
  return [...inspections].sort((a, b) => dateMs(b.date) - dateMs(a.date));
}

export async function getCustomers(): Promise<Customer[]> {
  try {
    const records = await queryRecords('CD_Customer', [], { fieldName: 'CD_name', ascending: true });
    return records.map(decodeCustomer);
  } catch (err) {
    logger.error('CloudKit getCustomers failed', err);
    throw err;
  }
}

export async function getCustomerById(id: string): Promise<Customer | null> {
  const record = await fetchRecord(id, 'CD_Customer');
  if (!record) return null;
  return decodeCustomer(record);
}

/**
 * Inspections for a customer. CD_customer is a Core Data REFERENCE, so this
 * queries all CD_Inspection records and filters in the browser.
 */
export async function getInspectionsByCustomerId(customerId: string): Promise<Inspection[]> {
  try {
    const records = await queryRecords('CD_Inspection');
    const matched = records.filter(
      (r) => extractRecordName(r.fields.CD_customer?.value) === customerId
    );
    logger.debug(`[CloudKit] getInspectionsByCustomerId: ${matched.length} inspections matched`);
    return sortInspectionsByDateDesc(matched.map(decodeInspection));
  } catch (err) {
    logger.error('CloudKit getInspectionsByCustomerId failed', err);
    throw err;
  }
}

export async function getAllInspections(): Promise<Inspection[]> {
  try {
    const records = await queryRecords('CD_Inspection');
    return sortInspectionsByDateDesc(records.map(decodeInspection));
  } catch (err) {
    logger.error('CloudKit getAllInspections failed', err);
    throw err;
  }
}

export async function getInspectionById(id: string): Promise<Inspection | null> {
  const r = await fetchRecord(id, 'CD_Inspection');
  if (!r) return null;
  const inspection = decodeInspection(r);
  if (inspection.customerId) {
    inspection.customer = (await getCustomerById(inspection.customerId)) || undefined;
  }

  const itemRecords = await queryRecords(
    'CD_InspectionItem',
    [],
    { fieldName: 'CD_sequenceNumber', ascending: true }
  );
  const items = itemRecords
    .filter((item) => extractRecordName(item.fields.CD_inspection?.value) === id)
    .map(decodeInspectionItem);
  items.sort((a, b) => a.sequenceNumber - b.sequenceNumber);
  inspection.items = items;
  return inspection;
}
