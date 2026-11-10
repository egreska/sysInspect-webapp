export function recordedOrder<T extends { sequenceNumber: number }>(items: readonly T[]): T[] {
  return items
    .map((item, index) => ({ item, index }))
    .sort((a, b) => a.item.sequenceNumber - b.item.sequenceNumber || a.index - b.index)
    .map(({ item }) => item);
}
