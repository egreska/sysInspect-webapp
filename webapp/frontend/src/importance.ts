export const NEEDS_IMMEDIATE_ATTENTION = 'Needs immediate attention';
export const MONITOR = 'Monitor';

export type Importance = typeof NEEDS_IMMEDIATE_ATTENTION | typeof MONITOR;

export const importanceValues: readonly Importance[] = [NEEDS_IMMEDIATE_ATTENTION, MONITOR];

export function importanceFromStored(raw: unknown): Importance {
  if (raw === NEEDS_IMMEDIATE_ATTENTION || raw === 'Critical') {
    return NEEDS_IMMEDIATE_ATTENTION;
  }
  return MONITOR;
}

export function isImmediate(importance: Importance): boolean {
  return importance === NEEDS_IMMEDIATE_ATTENTION;
}

export function importancePhrase(importance: Importance): string {
  return importance;
}

export function toggledImportance(importance: Importance): Importance {
  return isImmediate(importance) ? MONITOR : NEEDS_IMMEDIATE_ATTENTION;
}

export function compareImportance(left: Importance, right: Importance): number {
  if (left === right) return 0;
  return isImmediate(left) ? -1 : 1;
}

export interface ImportanceCounts {
  immediate: number;
  monitor: number;
}

export function importanceCounts(values: readonly Importance[]): ImportanceCounts {
  let immediate = 0;
  let monitor = 0;
  for (const value of values) {
    if (isImmediate(value)) immediate += 1;
    else monitor += 1;
  }
  return { immediate, monitor };
}
