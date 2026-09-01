import { logger } from '../utils/logger';
import type { LoadAdapter } from './load';
import { fetchRecord, queryRecords } from './cloudkit';
import { decodeCustomer } from './customerCodec';
import { decodeInspection } from './inspectionCodec';
import { decodeInspectionItem } from './inspectionItemCodec';

export const cloudKitAdapter: LoadAdapter = {
  async customers() {
    try {
      const records = await queryRecords('CD_Customer');
      return records.map(decodeCustomer);
    } catch (err) {
      logger.error('CloudKit customers failed', err);
      throw err;
    }
  },

  async customer(id) {
    const record = await fetchRecord(id, 'CD_Customer');
    if (!record) return null;
    return decodeCustomer(record);
  },

  async inspections() {
    try {
      const records = await queryRecords('CD_Inspection');
      return records.map(decodeInspection);
    } catch (err) {
      logger.error('CloudKit inspections failed', err);
      throw err;
    }
  },

  async inspection(id) {
    const record = await fetchRecord(id, 'CD_Inspection');
    if (!record) return null;
    return decodeInspection(record);
  },

  async items() {
    try {
      const records = await queryRecords('CD_InspectionItem');
      return records.map(decodeInspectionItem);
    } catch (err) {
      logger.error('CloudKit inspection items failed', err);
      throw err;
    }
  },
};
