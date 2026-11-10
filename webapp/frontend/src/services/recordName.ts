/**
 * CloudKit JS may return reference values as a string (recordName),
 * an object { recordName }, or { value: { recordName } }. Normalize to string.
 */
export function extractRecordName(ref: unknown): string | undefined {
  if (!ref) return undefined;
  if (typeof ref === 'string') return ref;
  if (typeof ref === 'object') {
    const obj = ref as Record<string, unknown>;
    if (typeof obj.recordName === 'string') return obj.recordName;
    if (typeof obj.value === 'string') return obj.value;
    if (typeof obj.value === 'object' && obj.value) {
      const inner = obj.value as Record<string, unknown>;
      if (typeof inner.recordName === 'string') return inner.recordName;
    }
  }
  return undefined;
}
