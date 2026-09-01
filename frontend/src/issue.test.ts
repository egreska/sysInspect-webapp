import { describe, expect, it } from 'vitest';
import { Issue, type IssuePath } from './issue';

const damage: IssuePath = { segments: ['Upright', 'Front', 'Damage'] };
const upright: IssuePath = { segments: ['Upright'] };
const bracing: IssuePath = { segments: ['Bracing Damage'] };
const bracingHorizontal: IssuePath = { segments: ['Bracing Damage', 'Horizontal'] };

describe('Issue.labels', () => {
  it('is empty when no paths', () => {
    expect(Issue.labels([])).toEqual([]);
  });

  it('lists a parent-only path', () => {
    expect(Issue.labels([upright])).toEqual(['• Upright']);
  });

  it('lists a hierarchical leaf', () => {
    expect(Issue.labels([damage])).toEqual(['• Upright > Front > Damage']);
  });

  it('lists bracing child and parent-only', () => {
    expect(Issue.labels([bracingHorizontal])).toEqual(['• Bracing Damage > Horizontal']);
    expect(Issue.labels([bracing])).toEqual(['• Bracing Damage']);
  });

  it('lists multiple recorded paths in catalog order', () => {
    expect(Issue.labels([damage, bracingHorizontal])).toEqual([
      '• Upright > Front > Damage',
      '• Bracing Damage > Horizontal',
    ]);
  });
});

describe('Issue Flag conversion', () => {
  it('infers ancestor flags from a leaf path', () => {
    const flags = Issue.flagsFromPaths([damage]);
    expect(flags.upright).toBe(true);
    expect(flags.uprightFrontDamage).toBe(true);
    expect(flags.uprightRearDamage).toBe(false);
    expect(flags.beam).toBe(false);
  });

  it('sets only the parent flag for a parent path', () => {
    const flags = Issue.flagsFromPaths([upright]);
    expect(flags.upright).toBe(true);
    expect(flags.uprightFrontDamage).toBe(false);
  });

  it('round-trips flags through selected paths', () => {
    const flags = Issue.flagsFromPaths([damage, bracingHorizontal]);
    const restored = Issue.selectedPaths(flags);
    expect(Issue.flagsFromPaths(restored)).toEqual(flags);
  });
});
