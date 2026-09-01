import { describe, expect, it } from 'vitest';
import { shouldFetchNextQueryPage } from './cloudkit';

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
