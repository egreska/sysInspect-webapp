import axios from 'axios';
import type { Customer, Inspection, LoginRequest, LoginResponse } from '../types';

const API_URL = import.meta.env.VITE_API_URL || '/api';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle 401 responses
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const authAPI = {
  login: async (credentials: LoginRequest): Promise<LoginResponse> => {
    const { data } = await api.post('/auth/login', credentials);
    return data;
  },

  verify: async (): Promise<{ valid: boolean; user: any }> => {
    const { data } = await api.post('/auth/verify');
    return data;
  },
};

export const customersAPI = {
  getAll: async (): Promise<Customer[]> => {
    const { data } = await api.get('/customers');
    return data;
  },

  getById: async (id: string): Promise<Customer> => {
    const { data } = await api.get(`/customers/${id}`);
    return data;
  },

  getInspections: async (id: string): Promise<Inspection[]> => {
    const { data } = await api.get(`/customers/${id}/inspections`);
    return data;
  },
};

export const inspectionsAPI = {
  getById: async (id: string): Promise<Inspection> => {
    const { data } = await api.get(`/inspections/${id}`);
    return data;
  },
};

export const reportsAPI = {
  generatePDF: async (inspectionId: string): Promise<Blob> => {
    const { data } = await api.get(`/reports/inspection/${inspectionId}`, {
      responseType: 'blob',
    });
    return data;
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

export default api;
