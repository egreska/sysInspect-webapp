/**
 * CloudKit JS Browser SDK Service
 *
 * Wraps Apple's CloudKit JS for Systems Inspector.
 * Uses Sign in with Apple for private database access.
 * Core Data + CloudKit uses CD_ prefix and com.apple.coredata.cloudkit.zone.
 */

declare global {
  interface Window {
    CloudKit?: typeof CloudKitNamespace;
    cloudkitloaded?: () => void;
  }
}

// CloudKit JS types (simplified - the CDN script doesn't ship types)
interface CloudKitNamespace {
  configure: (config: CloudKitConfig) => void;
  getDefaultContainer: () => CloudKitContainer;
  getContainer: (id: string) => CloudKitContainer;
}

interface CloudKitConfig {
  locale?: string;
  containers: CloudKitContainerConfig[];
}

interface CloudKitContainerConfig {
  containerIdentifier: string;
  environment: 'development' | 'production';
  apiTokenAuth: {
    apiToken: string;
    persist?: boolean;
    signInButton: { id: string; theme?: 'black' | 'white' | 'white-with-outline' };
    signOutButton: { id: string; theme?: 'black' | 'white' | 'white-with-outline' };
  };
}

interface CloudKitContainer {
  setUpAuth: () => Promise<CloudKitUserIdentity | null>;
  whenUserSignsIn: Promise<CloudKitUserIdentity>;
  whenUserSignsOut: Promise<void>;
  privateCloudDatabase: CloudKitDatabase;
}

interface CloudKitDatabase {
  performQuery: (query: CloudKitQuery) => Promise<CloudKitQueryResponse>;
  fetchRecords: (request: CloudKitFetchRequest) => Promise<CloudKitFetchResponse>;
}

interface CloudKitUserIdentity {
  userRecordName?: string;
  nameComponents?: { givenName?: string; familyName?: string };
  lookupInfo?: { emailAddress?: string };
}

interface CloudKitQuery {
  recordType: string;
  filterBy?: Array<{
    fieldName: string;
    comparator: string;
    fieldValue: { value: unknown; type: string };
  }>;
  sortBy?: Array<{ fieldName: string; ascending: boolean }>;
}

interface CloudKitQueryRequest {
  query: CloudKitQuery;
  zoneID: { zoneName: string };
  resultsLimit?: number;
  continuationMarker?: unknown;
}

interface CloudKitQueryResponse {
  records: CloudKitRecord[];
  continuationMarker?: unknown;
  moreComing?: boolean;
}

interface CloudKitFetchRequest {
  records: Array<{ recordName: string }>;
  zoneID: { zoneName: string };
}

interface CloudKitFetchResponse {
  records: CloudKitRecord[];
}

export interface CloudKitRecord {
  recordName: string;
  recordType: string;
  fields: Record<string, { value?: unknown }>;
}

const ZONE = 'com.apple.coredata.cloudkit.zone';

let container: CloudKitContainer | null = null;
let configured = false;

/**
 * Wait for CloudKit JS to load, then configure
 */
export function initCloudKit(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (window.CloudKit) {
      doConfigure(resolve, reject);
      return;
    }
    const handler = () => {
      window.removeEventListener('cloudkitloaded', handler);
      doConfigure(resolve, reject);
    };
    window.addEventListener('cloudkitloaded', handler);
    // Timeout in case script fails to load
    setTimeout(() => {
      if (!configured) {
        window.removeEventListener('cloudkitloaded', handler);
        reject(new Error('CloudKit JS failed to load'));
      }
    }, 10000);
  });
}

function doConfigure(resolve: () => void, reject: (err: Error) => void) {
  const containerId = import.meta.env.VITE_CLOUDKIT_CONTAINER_ID;
  const apiToken = import.meta.env.VITE_CLOUDKIT_API_TOKEN;
  const environment = (import.meta.env.VITE_CLOUDKIT_ENVIRONMENT || 'production') as 'development' | 'production';

  if (!containerId || !apiToken) {
    reject(new Error('CloudKit not configured: set VITE_CLOUDKIT_CONTAINER_ID and VITE_CLOUDKIT_API_TOKEN'));
    return;
  }

  try {
    window.CloudKit!.configure({
      locale: 'en-us',
      containers: [
        {
          containerIdentifier: containerId,
          environment,
          apiTokenAuth: {
            apiToken,
            persist: true,
            signInButton: { id: 'apple-sign-in-button', theme: 'black' },
            signOutButton: { id: 'apple-sign-out-button', theme: 'black' },
          },
        },
      ],
    });
    container = window.CloudKit!.getDefaultContainer();
    configured = true;
    resolve();
  } catch (err) {
    reject(err instanceof Error ? err : new Error(String(err)));
  }
}

/**
 * Set up auth (Sign in with Apple). Call when login page mounts.
 * Resolves with userIdentity if already signed in, null otherwise.
 */
export async function setUpAuth(): Promise<CloudKitUserIdentity | null> {
  if (!container) throw new Error('CloudKit not initialized');
  return container.setUpAuth();
}

/**
 * Promise that resolves when user signs in
 */
export function whenUserSignsIn(): Promise<CloudKitUserIdentity> {
  if (!container) throw new Error('CloudKit not initialized');
  return container.whenUserSignsIn;
}

/**
 * Promise that resolves when user signs out
 */
export function whenUserSignsOut(): Promise<void> {
  if (!container) throw new Error('CloudKit not initialized');
  return container.whenUserSignsOut;
}

/**
 * Get current user identity (if signed in)
 */
export function getContainer(): CloudKitContainer {
  if (!container) throw new Error('CloudKit not initialized');
  return container;
}

/**
 * Query records from CloudKit (Core Data + CloudKit zone)
 */
export async function queryRecords(
  recordType: string,
  filters: Array<{ fieldName: string; comparator: string; fieldValue: { value: unknown; type: string } }> = [],
  sortBy?: { fieldName: string; ascending: boolean },
  resultsLimit = 100
): Promise<CloudKitRecord[]> {
  const db = getContainer().privateCloudDatabase;
  const query: CloudKitQuery = {
    recordType,
    filterBy: filters.length > 0 ? filters : undefined,
    sortBy: sortBy ? [sortBy] : undefined,
  };
  const request = {
    query,
    zoneID: { zoneName: ZONE },
    resultsLimit,
  };
  const response = await db.performQuery(request);
  return response.records || [];
}

/**
 * Fetch records by name
 */
export async function fetchRecords(recordNames: string[]): Promise<CloudKitRecord[]> {
  if (recordNames.length === 0) return [];
  const db = getContainer().privateCloudDatabase;
  const request: CloudKitFetchRequest = {
    records: recordNames.map((recordName) => ({ recordName })),
    zoneID: { zoneName: ZONE },
  };
  const response = await db.fetchRecords(request);
  return response.records || [];
}

/**
 * Fetch a single record by name
 */
export async function fetchRecord(recordName: string): Promise<CloudKitRecord | null> {
  const records = await fetchRecords([recordName]);
  return records[0] || null;
}

// --- Domain helpers (Core Data + CloudKit uses CD_ prefix) ---

export async function fetchCustomers(userId: string): Promise<CloudKitRecord[]> {
  return queryRecords(
    'CD_Customer',
    [{ fieldName: 'CD_userId', comparator: 'EQUALS', fieldValue: { value: userId, type: 'STRING' } }],
    { fieldName: 'CD_name', ascending: true }
  );
}

export async function fetchInspections(customerId: string): Promise<CloudKitRecord[]> {
  return queryRecords(
    'CD_Inspection',
    [
      {
        fieldName: 'CD_customer',
        comparator: 'EQUALS',
        fieldValue: { value: { recordName: customerId }, type: 'REFERENCE' },
      },
    ],
    { fieldName: 'CD_date', ascending: false }
  );
}

export async function fetchInspectionItems(inspectionId: string): Promise<CloudKitRecord[]> {
  return queryRecords(
    'CD_InspectionItem',
    [
      {
        fieldName: 'CD_inspection',
        comparator: 'EQUALS',
        fieldValue: { value: { recordName: inspectionId }, type: 'REFERENCE' },
      },
    ],
    { fieldName: 'CD_sequenceNumber', ascending: true }
  );
}

/**
 * Map CloudKit CD_Customer record to Customer type
 */
export function mapCustomerRecord(r: CloudKitRecord) {
  return {
    id: r.recordName,
    name: (r.fields.CD_name?.value as string) || '',
    contactName: (r.fields.CD_contactName?.value as string) || '',
    phone: (r.fields.CD_phone?.value as string) || '',
    address: (r.fields.CD_address?.value as string) || '',
    city: (r.fields.CD_city?.value as string) || '',
    state: (r.fields.CD_state?.value as string) || '',
    zipCode: (r.fields.CD_zipCode?.value as string) || '',
    site: (r.fields.CD_site?.value as string) || '',
    createdDate: (r.fields.CD_createdDate?.value as string) || '',
  };
}

/**
 * Map CloudKit CD_Inspection record to Inspection type
 */
export function mapInspectionRecord(r: CloudKitRecord) {
  return {
    id: r.recordName,
    date: r.fields.CD_date?.value as string | undefined,
    inspectorName: (r.fields.CD_inspectorName?.value as string) || '',
    customerId: (r.fields.CD_customer?.value as { recordName?: string })?.recordName,
    createdDate: r.fields.CD_date?.value as string | undefined,
  };
}
