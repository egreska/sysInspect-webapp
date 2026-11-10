import { describe, expect, it } from 'vitest';
import { recordedOrder } from './recordedOrder';

describe('recordedOrder', () => {
  it('puts a lower sequence first', () => {
    const ordered = recordedOrder([
      { id: 'bay2', sequenceNumber: 2 },
      { id: 'bay10', sequenceNumber: 1 },
    ]);
    expect(ordered.map((row) => row.id)).toEqual(['bay10', 'bay2']);
  });

  it('keeps arrival order when sequences match', () => {
    const ordered = recordedOrder([
      { id: 'first', sequenceNumber: 0 },
      { id: 'second', sequenceNumber: 0 },
      { id: 'third', sequenceNumber: 0 },
    ]);
    expect(ordered.map((row) => row.id)).toEqual(['first', 'second', 'third']);
  });
});
