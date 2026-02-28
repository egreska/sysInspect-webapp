/**
 * CloudKit JS Browser SDK Service
 *
 * Wraps Apple's CloudKit JS for Systems Inspector.
 * Must match iOS app configuration:
 * - Container: iCloud.SysInspectDB (from Systems Inspector.entitlements)
 * - Private Database: container.privateCloudDatabase (user-scoped data)
 * - Zone: com.apple.coredata.cloudkit.zone (Core Data + CloudKit)
 * - Record types: CD_ prefix (CD_Customer, CD_Inspection, CD_InspectionItem)
 * - Environment: defaults to development (Xcode debug builds)
 */

declare global {
  interface Window {
    CloudKit?: CloudKitGlobal;
    cloudkitloaded?: () => void;
  }
}

// CloudKit JS types (simplified - the CDN script doesn't ship types)
interface CloudKitGlobal {
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
  performQuery: (request: CloudKitQueryRequest) => Promise<CloudKitQueryResponse>;
  fetchRecords: (request: CloudKitFetchRequest) => Promise<CloudKitFetchResponse>;
}

export interface CloudKitUserIdentity {
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

/** Core Data + CloudKit zone (required for CD_ record types) */
const ZONE = 'com.apple.coredata.cloudkit.zone';

let container: CloudKitContainer | null = null;
let configured = false;
let currentEnvironment: 'development' | 'production' = 'development';

/**
 * Wait for CloudKit JS to load, then configure
 */
export function initCloudKit(): Promise<void> {
  if (configured && container) return Promise.resolve();

  return new Promise((resolve, reject) => {
    let settled = false;
    const previousCloudKitLoaded = window.cloudkitloaded;
    let callbackInstalled = false;

    const restoreCloudKitLoaded = () => {
      if (!callbackInstalled) return;
      if (window.cloudkitloaded === onCloudKitLoaded) {
        window.cloudkitloaded = previousCloudKitLoaded;
      }
      callbackInstalled = false;
    };

    const timeoutId = setTimeout(() => {
      if (!settled && !configured) {
        settled = true;
        restoreCloudKitLoaded();
        reject(new Error('CloudKit JS failed to load'));
      }
    }, 10000);

    const onResolve = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutId);
      restoreCloudKitLoaded();
      resolve();
    };
    const onReject = (err: Error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutId);
      restoreCloudKitLoaded();
      reject(err);
    };

    const onCloudKitLoaded = () => {
      if (!window.CloudKit) return;
      // Preserve any previous callback behavior if it exists.
      if (typeof previousCloudKitLoaded === 'function' && previousCloudKitLoaded !== onCloudKitLoaded) {
        try {
          previousCloudKitLoaded();
        } catch {
          // Ignore callback errors from previous handlers.
        }
      }
      doConfigure(onResolve, onReject);
    };

    if (window.CloudKit) {
      doConfigure(onResolve, onReject);
      return;
    }

    window.cloudkitloaded = onCloudKitLoaded;
    callbackInstalled = true;
  });
}

function doConfigure(resolve: () => void, reject: (err: Error) => void) {
  const containerId = import.meta.env.VITE_CLOUDKIT_CONTAINER_ID;
  const apiToken = import.meta.env.VITE_CLOUDKIT_API_TOKEN;
  const environment = (import.meta.env.VITE_CLOUDKIT_ENVIRONMENT || 'development') as 'development' | 'production';
  currentEnvironment = environment;

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
 * Get current CloudKit environment (for debugging / troubleshooting).
 * Development and production have separate data - must match where your data lives.
 */
export function getCloudKitEnvironment(): 'development' | 'production' {
  return currentEnvironment;
}

/**
 * Get current user identity (if signed in)
 */
export function getContainer(): CloudKitContainer {
  if (!container) throw new Error('CloudKit not initialized');
  return container;
}

/**
 * Programmatically trigger the CloudKit sign-out button.
 * CloudKit JS has no direct sign-out API; the button must be clicked.
 */
export function triggerSignOut(): void {
  const el = document.getElementById('apple-sign-out-button');
  const button = el?.querySelector('button, a, [role="button"]') ?? el?.firstElementChild ?? el;
  if (button instanceof HTMLElement) {
    button.click();
  }
}

/**
 * Query records from CloudKit Private Database (Core Data + CloudKit zone).
 * Uses container.privateCloudDatabase and com.apple.coredata.cloudkit.zone.
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
  const allRecords: CloudKitRecord[] = [];
  let continuationMarker: unknown | undefined;

  do {
    const request: CloudKitQueryRequest = {
      query,
      zoneID: { zoneName: ZONE },
      resultsLimit,
      continuationMarker,
    };
    const response = await db.performQuery(request);
    if (response.records?.length) {
      allRecords.push(...response.records);
    }
    continuationMarker = response.continuationMarker;
    if (!response.moreComing || !continuationMarker) break;
  } while (true);

  return allRecords;
}

/**
 * Fetch records by name from Private Database (com.apple.coredata.cloudkit.zone).
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
