import { Issue, ISSUE_FLAGS, type IssueFlagMap } from '../issue';
import type { InspectionItem } from '../types';
import { extractRecordName } from './cloudkit';

export type InspectionItemCloudKitRecord = {
  recordName: string;
  fields: Record<string, { value?: unknown } | undefined>;
};

const NEEDS_IMMEDIATE_ATTENTION = 'Needs immediate attention';
const MONITOR = 'Monitor';

function decodeImportance(raw: unknown): InspectionItem['importance'] {
  if (raw === NEEDS_IMMEDIATE_ATTENTION || raw === 'Critical') {
    return NEEDS_IMMEDIATE_ATTENTION;
  }
  return MONITOR;
}

function extractDownloadURL(field: { value?: unknown } | undefined): string | null {
  if (!field || field.value == null) return null;
  const v = field.value;
  if (typeof v === 'object') {
    const obj = v as Record<string, unknown>;
    if (typeof obj.downloadURL === 'string') return obj.downloadURL;
    if (obj.value && typeof (obj.value as Record<string, unknown>).downloadURL === 'string') {
      return (obj.value as Record<string, unknown>).downloadURL as string;
    }
  }
  if (typeof v === 'string' && v.startsWith('http')) return v;
  return null;
}

function extractPhotoUrls(fields: InspectionItemCloudKitRecord['fields']): string[] {
  const groups = [
    ['CD_photoData_ckAsset', 'CD_photoData', 'CD_photoURL'],
    ['CD_photoData2_ckAsset', 'CD_photoData2', 'CD_photoURL2'],
    ['CD_photoData3_ckAsset', 'CD_photoData3', 'CD_photoURL3'],
    ['CD_photoData4_ckAsset', 'CD_photoData4', 'CD_photoURL4'],
    ['CD_photoData5_ckAsset', 'CD_photoData5', 'CD_photoURL5'],
  ];
  const urls: string[] = [];
  for (const keys of groups) {
    let found: string | null = null;
    for (const key of keys) {
      found = extractDownloadURL(fields[key]);
      if (found) break;
    }
    if (found) urls.push(found);
  }
  return urls;
}

export function decodeInspectionItem(record: InspectionItemCloudKitRecord): InspectionItem {
  const fields = record.fields;
  const flags = Object.fromEntries(
    ISSUE_FLAGS.map((name) => [name, !!(fields[`CD_${name}`]?.value)])
  ) as IssueFlagMap;

  return {
    id: record.recordName,
    inspectionId: extractRecordName(fields.CD_inspection?.value) ?? '',
    location: (fields.CD_location?.value as string) || '',
    bayNumber: (fields.CD_bayNumber?.value as string) || '',
    importance: decodeImportance(fields.CD_importance?.value),
    comments: (fields.CD_comments?.value as string) || '',
    sequenceNumber: (fields.CD_sequenceNumber?.value as number) || 0,
    photoUrls: extractPhotoUrls(fields),
    issues: Issue.selectedPaths(flags),
  };
}
