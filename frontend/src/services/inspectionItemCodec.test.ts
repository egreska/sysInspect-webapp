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
        CD_inspection: 'insp-1',
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
    expect(item.inspectionId).toBe('insp-1');
    expect(item.location).toBe('Aisle 3');
    expect(item.bayNumber).toBe('B2');
    expect(item.importance).toBe('Needs immediate attention');
    expect(item.comments).toBe('Column dented');
    expect(item.sequenceNumber).toBe(4);
    expect(item.issues).toEqual([
      { segments: ['Upright'] },
      { segments: ['Upright', 'Front', 'Damage'] },
    ]);
    expect(item.photoUrls).toEqual(['https://ck.example/photo.jpg']);
  });

  it('defaults Monitor, empty flags, and null photo', () => {
    const item = decodeInspectionItem(record({}));
    expect(item.inspectionId).toBe('');
    expect(item.importance).toBe('Monitor');
    expect(item.location).toBe('');
    expect(item.sequenceNumber).toBe(0);
    expect(item.issues).toEqual([]);
    expect(item.photoUrls).toEqual([]);
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
    expect(item.photoUrls).toEqual(['https://ck.example/from-string.jpg']);
  });

  it('collects multiple photo asset URLs in slot order', () => {
    const item = decodeInspectionItem(
      record({
        CD_photoData_ckAsset: { downloadURL: 'https://ck.example/one.jpg' },
        CD_photoData2_ckAsset: { downloadURL: 'https://ck.example/two.jpg' },
        CD_photoData4: { downloadURL: 'https://ck.example/four.jpg' },
      })
    );
    expect(item.photoUrls).toEqual([
      'https://ck.example/one.jpg',
      'https://ck.example/two.jpg',
      'https://ck.example/four.jpg',
    ]);
  });

  it('decodes a recordName object inspection reference', () => {
    const item = decodeInspectionItem(
      record({ CD_inspection: { recordName: 'insp-9' } })
    );
    expect(item.inspectionId).toBe('insp-9');
  });
});
