import { describe, expect, it } from 'vitest';
import {
  inspectionItemQueryFilters,
  inspectionQueryFilters,
  queryHitPageGuard,
  shouldFetchNextQueryPage,
} from './cloudkit';

describe('shouldFetchNextQueryPage', () => {
  it('continues when CloudKit omits moreComing but sends a continuation marker', () => {
    expect(shouldFetchNextQueryPage({ continuationMarker: 'abc' })).toBe(true);
  });

  it('continues when moreComing is true and a marker is present', () => {
    expect(
      shouldFetchNextQueryPage({ moreComing: true, continuationMarker: 'abc' })
    ).toBe(true);
  });

  it('stops when moreComing is false even if a marker is present', () => {
    expect(
      shouldFetchNextQueryPage({ moreComing: false, continuationMarker: 'abc' })
    ).toBe(false);
  });

  it('stops when moreComing is true but there is no marker', () => {
    expect(shouldFetchNextQueryPage({ moreComing: true })).toBe(false);
  });

  it('stops on an empty response', () => {
    expect(shouldFetchNextQueryPage({})).toBe(false);
  });
});

describe('inspectionQueryFilters', () => {
  it('asks CloudKit for inspections linked to that customer', () => {
    const [filter] = inspectionQueryFilters('cust-1');
    expect(filter).toEqual({
      fieldName: 'CD_customer',
      comparator: 'EQUALS',
      fieldValue: {
        value: {
          recordName: 'cust-1',
          action: 'NONE',
          zoneID: { zoneName: 'com.apple.coredata.cloudkit.zone' },
        },
        type: 'REFERENCE',
      },
    });
  });
});

describe('inspectionItemQueryFilters', () => {
  it('asks CloudKit for items linked to that inspection', () => {
    const [filter] = inspectionItemQueryFilters('insp-1');
    expect(filter).toEqual({
      fieldName: 'CD_inspection',
      comparator: 'EQUALS',
      fieldValue: {
        value: {
          recordName: 'insp-1',
          action: 'NONE',
          zoneID: { zoneName: 'com.apple.coredata.cloudkit.zone' },
        },
        type: 'REFERENCE',
      },
    });
  });
});

describe('queryHitPageGuard', () => {
  it('is the guard only when CloudKit still has another page', () => {
    const more = { continuationMarker: 'next' };
    expect(queryHitPageGuard(50, more)).toBe(true);
    expect(queryHitPageGuard(49, more)).toBe(false);
    expect(queryHitPageGuard(50, { moreComing: false, continuationMarker: 'next' })).toBe(false);
  });
});
