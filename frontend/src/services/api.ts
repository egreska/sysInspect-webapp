/**
 * API layer - uses CloudKit JS for data (replaces backend).
 * Auth is handled by CloudKit Sign in with Apple.
 */
import type { Customer, Inspection } from '../types';
import {
  getCustomers,
  getCustomerById,
  getInspectionsByCustomerId,
  getAllInspections,
  getInspectionById,
} from './cloudkitApi';

export const customersAPI = {
  getAll: async (): Promise<Customer[]> => getCustomers(),

  getById: async (id: string): Promise<Customer> => {
    const c = await getCustomerById(id);
    if (!c) throw new Error('Customer not found');
    return c;
  },

  getInspections: async (id: string): Promise<Inspection[]> =>
    getInspectionsByCustomerId(id),
};

export const inspectionsAPI = {
  getAll: async (): Promise<Inspection[]> => getAllInspections(),

  getById: async (id: string): Promise<Inspection> => {
    const i = await getInspectionById(id);
    if (!i) throw new Error('Inspection not found');
    return i;
  },
};
