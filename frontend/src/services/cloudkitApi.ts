/**
 * CloudKit JS-based API - replaces backend for data access.
 * Uses Sign in with Apple for auth; fetches directly from CloudKit.
 */
import type { Customer, Inspection, InspectionItem } from '../types';
import {
  fetchRecord,
  fetchInspections,
  fetchInspectionItems,
  mapCustomerRecord,
  mapInspectionRecord,
  queryRecords,
  extractRecordName,
} from './cloudkit';

/**
 * Fetch all customers. Private database is scoped to the signed-in iCloud user,
 * so we get only their data. Query all CD_Customer in the zone.
 */
export async function getCustomers(): Promise<Customer[]> {
  try {
    const records = await queryRecords('CD_Customer', [], { fieldName: 'CD_name', ascending: true });
    return records.map(mapCustomerRecord);
  } catch (err) {
    console.error('CloudKit getCustomers failed:', err);
    throw err;
  }
}

export async function getCustomerById(id: string): Promise<Customer | null> {
  const record = await fetchRecord(id, 'CD_Customer');
  if (!record) return null;
  return mapCustomerRecord(record);
}

export async function getInspectionsByCustomerId(customerId: string): Promise<Inspection[]> {
  try {
    const records = await fetchInspections(customerId);
    console.debug(`[CloudKit] getInspectionsByCustomerId(${customerId}): ${records.length} inspections matched`);
    return records.map(mapInspectionRecord);
  } catch (err) {
    console.error('CloudKit getInspectionsByCustomerId failed:', err);
    throw err;
  }
}

async function mapInspectionItem(r: import('./cloudkit').CloudKitRecord): Promise<InspectionItem> {
  const photoVal = r.fields.CD_photoData?.value as { downloadURL?: string } | undefined;
  let photoData: string | null = null;
  if (photoVal?.downloadURL) {
    try {
      const resp = await fetch(photoVal.downloadURL);
      if (resp.ok) {
        const blob = await resp.blob();
        const reader = new FileReader();
        photoData = await new Promise<string>((res, rej) => {
          reader.onload = () => res((reader.result as string).split(',')[1] || '');
          reader.onerror = rej;
          reader.readAsDataURL(blob);
        });
      }
    } catch {
      // Ignore photo fetch errors
    }
  }
  return {
    id: r.recordName,
    location: (r.fields.CD_location?.value as string) || '',
    bayNumber: (r.fields.CD_bayNumber?.value as string) || '',
    importance: (() => {
      const v = (r.fields.CD_importance?.value as string) || 'Monitor';
      if (v === 'Needs immediate attention') return 'Critical' as const;
      if (v === 'Critical' || v === 'Repair' || v === 'Monitor') return v;
      return 'Monitor' as const;
    })(),
    comments: (r.fields.CD_comments?.value as string) || '',
    sequenceNumber: (r.fields.CD_sequenceNumber?.value as number) || 0,
    photoData,
    upright: !!(r.fields.CD_upright?.value),
    beam: !!(r.fields.CD_beam?.value),
    bracingDiagonal: !!(r.fields.CD_bracingDiagonal?.value),
    bracingHorizontal: !!(r.fields.CD_bracingHorizontal?.value),
    basePlate: !!(r.fields.CD_basePlate?.value),
    anchors: !!(r.fields.CD_anchors?.value),
    wireDeck: !!(r.fields.CD_wireDeck?.value),
    postProtector: !!(r.fields.CD_postProtector?.value),
    aisleGuarding: !!(r.fields.CD_aisleGuarding?.value),
    uprightFrontDamage: !!(r.fields.CD_uprightFrontDamage?.value),
    uprightFrontTwisted: !!(r.fields.CD_uprightFrontTwisted?.value),
    uprightRearDamage: !!(r.fields.CD_uprightRearDamage?.value),
    uprightRearTwisted: !!(r.fields.CD_uprightRearTwisted?.value),
    uprightAlignmentOutOfAlignment: !!(r.fields.CD_uprightAlignmentOutOfAlignment?.value),
    uprightAlignmentOutOfVerticalPlumb: !!(r.fields.CD_uprightAlignmentOutOfVerticalPlumb?.value),
    beamFrontDamage: !!(r.fields.CD_beamFrontDamage?.value),
    beamFrontBowed: !!(r.fields.CD_beamFrontBowed?.value),
    beamRearDamage: !!(r.fields.CD_beamRearDamage?.value),
    beamRearBowed: !!(r.fields.CD_beamRearBowed?.value),
    bracingDamage: !!(r.fields.CD_bracingDamage?.value),
    basePlateDamaged: !!(r.fields.CD_basePlateDamaged?.value),
    basePlateTwisted: !!(r.fields.CD_basePlateTwisted?.value),
    basePlateFloorDamaged: !!(r.fields.CD_basePlateFloorDamaged?.value),
    anchorsDamaged: !!(r.fields.CD_anchorsDamaged?.value),
    anchorsMissing: !!(r.fields.CD_anchorsMissing?.value),
    anchorsTorqued: !!(r.fields.CD_anchorsTorqued?.value),
    wireDeckDamaged: !!(r.fields.CD_wireDeckDamaged?.value),
    wireDeckMissing: !!(r.fields.CD_wireDeckMissing?.value),
    wireDeckOutOfPosition: !!(r.fields.CD_wireDeckOutOfPosition?.value),
    postProtectorDamaged: !!(r.fields.CD_postProtectorDamaged?.value),
    postProtectorMissing: !!(r.fields.CD_postProtectorMissing?.value),
    postProtectorRepairRequired: !!(r.fields.CD_postProtectorRepairRequired?.value),
    aisleGuardingDamaged: !!(r.fields.CD_aisleGuardingDamaged?.value),
    aisleGuardingMissing: !!(r.fields.CD_aisleGuardingMissing?.value),
    aisleGuardingRepairRequired: !!(r.fields.CD_aisleGuardingRepairRequired?.value),
  };
}


export async function getInspectionById(id: string): Promise<Inspection | null> {
  const r = await fetchRecord(id, 'CD_Inspection');
  if (!r) return null;
  const customerId = extractRecordName(r.fields.CD_customer?.value);
  let customer: Customer | null = null;
  if (customerId) {
    customer = await getCustomerById(customerId);
  }

  const itemRecords = await fetchInspectionItems(id);
  const items = await Promise.all(itemRecords.map((ir) => mapInspectionItem(ir)));
  items.sort((a, b) => a.sequenceNumber - b.sequenceNumber);

  return {
    id: r.recordName,
    date: r.fields.CD_date?.value as string | undefined,
    inspectorName: (r.fields.CD_inspectorName?.value as string) || '',
    customerId,
    customer: customer || undefined,
    items,
    createdDate: r.fields.CD_date?.value as string | undefined,
  };
}
