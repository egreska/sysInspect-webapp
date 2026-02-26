/**
 * API layer - uses CloudKit JS for data (replaces backend).
 * Auth is handled by CloudKit Sign in with Apple.
 */
import type { Customer, Inspection } from '../types';
import {
  getCustomers,
  getCustomerById,
  getInspectionsByCustomerId,
  getInspectionById,
} from './cloudkitApi';
import { generatePDF } from './pdfGenerator';

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
  getById: async (id: string): Promise<Inspection> => {
    const i = await getInspectionById(id);
    if (!i) throw new Error('Inspection not found');
    return i;
  },
};

export const reportsAPI = {
  generatePDF: async (inspectionId: string): Promise<Blob> => {
    const inspection = await getInspectionById(inspectionId);
    if (!inspection) throw new Error('Inspection not found');
    return generatePDF(inspection);
  },

  downloadPDF: async (inspectionId: string, filename?: string) => {
    const blob = await reportsAPI.generatePDF(inspectionId);
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename || `inspection-report-${inspectionId}.pdf`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  },
};
