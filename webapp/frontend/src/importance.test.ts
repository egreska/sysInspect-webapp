import { describe, expect, it } from 'vitest';
import {
  compareImportance,
  importanceCounts,
  importanceFromStored,
  importancePhrase,
  isImmediate,
  MONITOR,
  NEEDS_IMMEDIATE_ATTENTION,
  toggledImportance,
} from './importance';

describe('importanceFromStored', () => {
  it('reads Needs immediate attention and Critical as immediate', () => {
    expect(importanceFromStored('Needs immediate attention')).toBe(NEEDS_IMMEDIATE_ATTENTION);
    expect(importanceFromStored('Critical')).toBe(NEEDS_IMMEDIATE_ATTENTION);
    expect(isImmediate(NEEDS_IMMEDIATE_ATTENTION)).toBe(true);
    expect(importancePhrase(NEEDS_IMMEDIATE_ATTENTION)).toBe('Needs immediate attention');
  });

  it('reads a missing value, Repair, Urgent, and any other word as Monitor', () => {
    expect(importanceFromStored(undefined)).toBe(MONITOR);
    expect(importanceFromStored(null)).toBe(MONITOR);
    expect(importanceFromStored('')).toBe(MONITOR);
    expect(importanceFromStored('Repair')).toBe(MONITOR);
    expect(importanceFromStored('Urgent')).toBe(MONITOR);
    expect(importanceFromStored('critical')).toBe(MONITOR);
    expect(importanceFromStored('   ')).toBe(MONITOR);
    expect(isImmediate(MONITOR)).toBe(false);
    expect(importancePhrase(MONITOR)).toBe('Monitor');
  });

  it('flips between the two values', () => {
    expect(toggledImportance(MONITOR)).toBe(NEEDS_IMMEDIATE_ATTENTION);
    expect(toggledImportance(NEEDS_IMMEDIATE_ATTENTION)).toBe(MONITOR);
  });

  it('sorts Needs immediate attention before Monitor', () => {
    const ordered = [MONITOR, NEEDS_IMMEDIATE_ATTENTION, MONITOR].sort(compareImportance);
    expect(ordered).toEqual([NEEDS_IMMEDIATE_ATTENTION, MONITOR, MONITOR]);
  });

  it('counts each value', () => {
    expect(
      importanceCounts([NEEDS_IMMEDIATE_ATTENTION, MONITOR, NEEDS_IMMEDIATE_ATTENTION])
    ).toEqual({ immediate: 2, monitor: 1 });
  });
});
