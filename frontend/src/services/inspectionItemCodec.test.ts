import { describe, expect, it } from 'vitest';
import { decodeInspectionItem } from './inspectionItemCodec';

function record(
  fields: Record<string, unknown>,
  recordName = 'item-1'
): { recordName: string; fields: Record<string, { value?: unknown }> } {
  const mapped: Record<string, { value?: unknown }> = {};
  for (const [key, value] of Object.entries(fields)) {
    mapped[key] = { value };
  }
  return { recordName, fields: mapped };
}

describe('decodeInspectionItem', () => {
  it('decodes NIA, a flag, and a photo asset URL', () => {
    const item = decodeInspectionItem(
      record({
        CD_location: 'Aisle 3',
        CD_bayNumber: 'B2',
        CD_importance: 'Needs immediate attention',
        CD_comments: 'Column dented',
        CD_sequenceNumber: 4,
        CD_upright: true,
        CD_uprightFrontDamage: true,
        CD_photoData_ckAsset: { downloadURL: 'https://ck.example/photo.jpg' },
      })
    );

    expect(item.id).toBe('item-1');
    expect(item.location).toBe('Aisle 3');
    expect(item.bayNumber).toBe('B2');
    expect(item.importance).toBe('Needs immediate attention');
    expect(item.comments).toBe('Column dented');
    expect(item.sequenceNumber).toBe(4);
    expect(item.upright).toBe(true);
    expect(item.uprightFrontDamage).toBe(true);
    expect(item.photoUrl).toBe('https://ck.example/photo.jpg');
    expect(item.photoData).toBeNull();
  });

  it('defaults Monitor, empty flags, and null photo', () => {
    const item = decodeInspectionItem(record({}));
    expect(item.importance).toBe('Monitor');
    expect(item.location).toBe('');
    expect(item.sequenceNumber).toBe(0);
    expect(item.upright).toBe(false);
    expect(item.beam).toBe(false);
    expect(item.uprightFrontDamage).toBe(false);
    expect(item.photoUrl).toBeNull();
    expect(item.photoData).toBeNull();
  });

  it('maps Critical to Needs immediate attention', () => {
    const item = decodeInspectionItem(record({ CD_importance: 'Critical' }));
    expect(item.importance).toBe('Needs immediate attention');
  });

  it('maps unknown importance including Repair to Monitor', () => {
    expect(decodeInspectionItem(record({ CD_importance: 'Repair' })).importance).toBe('Monitor');
    expect(decodeInspectionItem(record({ CD_importance: 'Urgent' })).importance).toBe('Monitor');
  });

  it('keeps Monitor', () => {
    expect(decodeInspectionItem(record({ CD_importance: 'Monitor' })).importance).toBe('Monitor');
  });

  it('resolves a string photo URL', () => {
    const item = decodeInspectionItem(
      record({ CD_photoURL: 'https://ck.example/from-string.jpg' })
    );
    expect(item.photoUrl).toBe('https://ck.example/from-string.jpg');
    expect(item.photoData).toBeNull();
  });
});
