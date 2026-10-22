import { logger } from '../utils/logger';
import type { LoadAdapter } from './load';
import { fetchRecord, inspectionItemQueryFilters, inspectionQueryFilters, queryRecords } from './cloudkit';
import { decodeCustomer } from './customerCodec';
import { decodeInspection } from './inspectionCodec';
import { decodeInspectionItem } from './inspectionItemCodec';

export const cloudKitAdapter: LoadAdapter = {
  async customers() {
    try {
      const { records, stoppedEarly } = await queryRecords('CD_Customer');
      return { rows: records.map(decodeCustomer), stoppedEarly };
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

  async inspections(customerId?: string) {
    try {
      const filters = customerId ? inspectionQueryFilters(customerId) : [];
      const { records, stoppedEarly } = await queryRecords('CD_Inspection', filters);
      return { rows: records.map(decodeInspection), stoppedEarly };
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

  async items(inspectionId) {
    try {
      const { records, stoppedEarly } = await queryRecords(
        'CD_InspectionItem',
        inspectionItemQueryFilters(inspectionId)
      );
      return { rows: records.map(decodeInspectionItem), stoppedEarly };
    } catch (err) {
      logger.error('CloudKit inspection items failed', err);
      throw err;
    }
  },
};
