import type { IssuePath } from '../issue';

export interface User {
  userId: string;
  email: string;
}

export interface Customer {
  id: string;
  name: string;
  contactName?: string;
  phone?: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  site?: string;
  createdDate?: string;
}

export interface Inspection {
  id: string;
  date?: string;
  inspectorName?: string;
  customerId?: string;
  customer?: Customer;
  items?: InspectionItem[];
  createdDate?: string;
}

export interface InspectionItem {
  id: string;
  inspectionId: string;
  location: string;
  bayNumber?: string;
  importance: 'Needs immediate attention' | 'Monitor';
  comments?: string;
  sequenceNumber: number;
  photoUrls: string[];
  issues: IssuePath[];
}
