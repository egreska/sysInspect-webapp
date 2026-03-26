import { logger } from '../utils/logger';

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
  performQuery: (query: CloudKitQuery, options?: CloudKitQueryOptions) => Promise<CloudKitQueryResponse>;
}

export interface CloudKitUserIdentity {
  userRecordName?: string;
  nameComponents?: { givenName?: string; familyName?: string };
  lookupInfo?: { emailAddress?: string };
}

/**
 * CloudKit JS performQuery(query, options?):
 * - query: { recordType, filterBy?, sortBy? }
 * - options: { zoneID?, resultsLimit?, continuationMarker?, desiredKeys? }
 */
interface CloudKitQuery {
  recordType: string;
  filterBy?: Array<{
    fieldName: string;
    comparator: string;
    fieldValue: { value: unknown };
  }>;
  sortBy?: { fieldName: string; ascending: boolean };
}

interface CloudKitQueryOptions {
  zoneID?: { zoneName: string };
  resultsLimit?: number;
  continuationMarker?: unknown;
  desiredKeys?: string[];
}

interface CloudKitQueryResponse {
  records: CloudKitRecord[];
  continuationMarker?: unknown;
  moreComing?: boolean;
}

export interface CloudKitRecord {
  recordName: string;
  recordType: string;
  fields: Record<string, { value?: unknown }>;
  serverErrorCode?: string;
  reason?: string;
}

// CloudKit JS error responses can be objects, arrays, or CKError wrappers
interface CloudKitError {
  ckErrorCode?: string;
  serverErrorCode?: string;
  reason?: string;
  message?: string;
  recordName?: string;
}

/** Core Data + CloudKit zone (required for CD_ record types) */
const ZONE = 'com.apple.coredata.cloudkit.zone';

/**
 * Limit fields returned by CloudKit (smaller payloads, less data in browser memory).
 * Omit for record types that need full field sets (e.g. CD_InspectionItem).
 */
export const QUERY_DESIRED_KEYS: Record<string, readonly string[]> = {
  CD_Customer: [
    'CD_name',
    'CD_contactName',
    'CD_phone',
    'CD_address',
    'CD_city',
    'CD_state',
    'CD_zipCode',
    'CD_site',
    'CD_createdDate',
  ],
  CD_Inspection: ['CD_date', 'CD_inspectorName', 'CD_customer'],
};

export interface QueryRecordsExtras {
  desiredKeys?: string[];
}

/**
 * Extract a readable error message from CloudKit JS error responses.
 * CloudKit JS rejects with various shapes: CKError objects, arrays of errors, or plain objects.
 */
function extractCloudKitError(err: unknown): string {
  if (!err) return 'Unknown CloudKit error';

  // Array of errors (CloudKit JS often rejects with an array)
  if (Array.isArray(err)) {
    const details = err.map((e: CloudKitError) =>
      e.ckErrorCode || e.serverErrorCode || e.reason || e.message || JSON.stringify(e)
    );
    return `CloudKit error: ${details.join('; ')}`;
  }

  // Object with ckErrorCode / serverErrorCode
  const obj = err as CloudKitError;
  if (obj.ckErrorCode || obj.serverErrorCode || obj.reason) {
    return `CloudKit ${obj.ckErrorCode || obj.serverErrorCode || ''}: ${obj.reason || obj.message || ''}`.trim();
  }

  // Standard Error
  if (err instanceof Error) return err.message;

  // Last resort
  try { return JSON.stringify(err); } catch { return String(err); }
}

let container: CloudKitContainer | null = null;
let configured = false;
let currentEnvironment: 'development' | 'production' = 'development';

/**
 * Wait for CloudKit JS to load, then configure.
 * Uses the 'cloudkitloaded' window event per Apple's documented async pattern:
 * https://cdn.apple-cloudkit.com/cloudkit-catalog/
 */
export function initCloudKit(): Promise<void> {
  if (configured && container) return Promise.resolve();

  return new Promise((resolve, reject) => {
    let settled = false;

    const timeoutId = setTimeout(() => {
      if (!settled && !configured) {
        settled = true;
        window.removeEventListener('cloudkitloaded', handler);
        reject(new Error('CloudKit JS failed to load'));
      }
    }, 10000);

    const onResolve = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutId);
      resolve();
    };
    const onReject = (err: Error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutId);
      reject(err);
    };

    const handler = () => {
      window.removeEventListener('cloudkitloaded', handler);
      doConfigure(onResolve, onReject);
    };

    if (window.CloudKit) {
      doConfigure(onResolve, onReject);
      return;
    }

    window.addEventListener('cloudkitloaded', handler);
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
 * CloudKit JS: database.performQuery(query, options?)
 *   query  = { recordType, filterBy?, sortBy? }
 *   options = { zoneID?, resultsLimit?, continuationMarker? }
 */
export async function queryRecords(
  recordType: string,
  filters: Array<{ fieldName: string; comparator: string; fieldValue: { value: unknown } }> = [],
  sortBy?: { fieldName: string; ascending: boolean },
  resultsLimit = 100,
  extras?: QueryRecordsExtras
): Promise<CloudKitRecord[]> {
  const db = getContainer().privateCloudDatabase;

  const allRecords: CloudKitRecord[] = [];
  let marker: unknown = null;

  do {
    const query: CloudKitQuery = { recordType };
    if (filters.length > 0) query.filterBy = filters;
    if (sortBy) query.sortBy = sortBy;

    const options: CloudKitQueryOptions = {
      zoneID: { zoneName: ZONE },
      resultsLimit,
    };
    if (marker) options.continuationMarker = marker;
    const presetKeys = QUERY_DESIRED_KEYS[recordType];
    const desiredKeys = extras?.desiredKeys ?? (presetKeys ? [...presetKeys] : undefined);
    if (desiredKeys?.length) options.desiredKeys = desiredKeys;

    let response: CloudKitQueryResponse;
    try {
      response = await Promise.resolve(db.performQuery(query, options));
    } catch (err) {
      const msg = extractCloudKitError(err);
      logger.error(`CloudKit performQuery failed for ${recordType}: ${msg}`, err);
      throw new Error(msg);
    }

    if (response.records?.length) {
      for (const rec of response.records) {
        if (rec.serverErrorCode) {
          logger.warn(`CloudKit record error: ${rec.serverErrorCode} - ${rec.reason || ''}`);
        } else {
          allRecords.push(rec);
        }
      }
    }
    marker = response.continuationMarker ?? null;
    if (!response.moreComing || !marker) break;
  } while (true);

  logger.debug(`[CloudKit] queryRecords(${recordType}): ${allRecords.length} records`);
  return allRecords;
}

/**
 * Fetch a single record by recordName from the Private Database.
 * Uses performQuery (which we know works) instead of fetchRecords (which has
 * an unclear API signature in CloudKit JS). Queries all records of the given
 * type and finds the one matching.  If recordType is unknown, tries each type.
 */
export async function fetchRecord(
  recordName: string,
  recordType?: string
): Promise<CloudKitRecord | null> {
  if (!recordName) return null;

  const types = recordType
    ? [recordType]
    : ['CD_Customer', 'CD_Inspection', 'CD_InspectionItem'];

  for (const rt of types) {
    const records = await queryRecords(rt, [], undefined, 100);
    const match = records.find((r) => r.recordName === recordName);
    if (match) {
      logger.debug(`[CloudKit] fetchRecord found record as ${rt}`);
      return match;
    }
  }
  logger.warn(`[CloudKit] fetchRecord: not found in types ${types.join(', ')}`);
  return null;
}

/**
 * CloudKit JS may return reference values as a string (recordName),
 * an object { recordName }, or { value: { recordName } }. Normalize to string.
 */
export function extractRecordName(ref: unknown): string | undefined {
  if (!ref) return undefined;
  if (typeof ref === 'string') return ref;
  if (typeof ref === 'object') {
    const obj = ref as Record<string, unknown>;
    if (typeof obj.recordName === 'string') return obj.recordName;
    if (typeof obj.value === 'string') return obj.value;
    if (typeof obj.value === 'object' && obj.value) {
      const inner = obj.value as Record<string, unknown>;
      if (typeof inner.recordName === 'string') return inner.recordName;
    }
  }
  return undefined;
}

// --- Domain helpers (Core Data + CloudKit uses CD_ prefix) ---

/**
 * Fetch inspections for a customer.  CD_customer is a REFERENCE field (Core Data
 * relationship), so we cannot reliably filter with EQUALS on a plain string.
 * Instead we fetch all CD_Inspection records and filter client-side.
 */
export async function fetchInspections(customerId: string): Promise<CloudKitRecord[]> {
  const all = await queryRecords(
    'CD_Inspection',
    [],
    { fieldName: 'CD_date', ascending: false }
  );
  logger.debug(`[CloudKit] fetched ${all.length} CD_Inspection records (client filter by customer)`);
  return all.filter((r) => {
    const ref = extractRecordName(r.fields.CD_customer?.value);
    return ref === customerId;
  });
}

/**
 * Fetch inspection items for an inspection.  CD_inspection is a REFERENCE field,
 * so we fetch all CD_InspectionItem records and filter client-side.
 */
export async function fetchInspectionItems(inspectionId: string): Promise<CloudKitRecord[]> {
  const all = await queryRecords(
    'CD_InspectionItem',
    [],
    { fieldName: 'CD_sequenceNumber', ascending: true }
  );
  logger.debug(`[CloudKit] fetched ${all.length} CD_InspectionItem records (client filter by inspection)`);
  return all.filter((r) => {
    const ref = extractRecordName(r.fields.CD_inspection?.value);
    return ref === inspectionId;
  });
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
    customerId: extractRecordName(r.fields.CD_customer?.value),
    createdDate: r.fields.CD_date?.value as string | undefined,
  };
}
