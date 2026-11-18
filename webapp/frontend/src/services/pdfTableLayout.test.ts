import { describe, expect, it } from 'vitest';
import { resolvePdfTableLayout, secondaryLocationText, type PdfColumnKind } from './pdfTableLayout';

const CONTENT_WIDTH = 720;

function kinds(items: { photoCount?: number; bayNumber?: string; comments?: string }[]): PdfColumnKind[] {
  return resolvePdfTableLayout(
    items.map((item) => ({ photoCount: item.photoCount ?? 0, bayNumber: item.bayNumber, comments: item.comments })),
    CONTENT_WIDTH
  ).map((column) => column.kind);
}

function width(kind: PdfColumnKind, items: { photoCount?: number; bayNumber?: string; comments?: string }[]): number {
  const column = resolvePdfTableLayout(
    items.map((item) => ({ photoCount: item.photoCount ?? 0, bayNumber: item.bayNumber, comments: item.comments })),
    CONTENT_WIDTH
  ).find((entry) => entry.kind === kind);
  if (!column) throw new Error(`missing ${kind}`);
  return column.width;
}

describe('resolvePdfTableLayout', () => {
  it('keeps primary, importance, and issue when photos, comments, and bays are empty', () => {
    expect(kinds([{}])).toEqual(['primaryLocation', 'importance', 'issue']);
    expect(width('issue', [{}])).toBe(CONTENT_WIDTH - 120 - 72);
    expect(kinds([{ bayNumber: '  ', comments: '  ' }])).toEqual(['primaryLocation', 'importance', 'issue']);
  });

  it('uses the existing widths when a photo and a comment are present', () => {
    const items = [{ photoCount: 1, comments: 'Rust' }];
    expect(kinds(items)).toEqual(['image', 'primaryLocation', 'importance', 'issue', 'comments']);
    expect(width('image', items)).toBe(60);
    expect(width('primaryLocation', items)).toBe(120);
    expect(width('importance', items)).toBe(72);
    expect(width('issue', items)).toBe(200);
    expect(width('comments', items)).toBe(CONTENT_WIDTH - 60 - 120 - 72 - 200);
  });

  it('adds secondary location when any bay has text and gives issue the rest without comments', () => {
    const items = [{ bayNumber: 'B2' }, { bayNumber: '' }];
    expect(kinds(items)).toEqual(['primaryLocation', 'secondaryLocation', 'importance', 'issue']);
    expect(width('secondaryLocation', items)).toBe(72);
    expect(width('issue', items)).toBe(CONTENT_WIDTH - 120 - 72 - 72);
  });

  it('sums to the content width', () => {
    const columns = resolvePdfTableLayout(
      [{ photoCount: 2, bayNumber: 'B1', comments: 'Note' }],
      CONTENT_WIDTH
    );
    expect(columns.reduce((sum, column) => sum + column.width, 0)).toBe(CONTENT_WIDTH);
  });
});

describe('secondaryLocationText', () => {
  it('prints the bay, or N/A when that row has none', () => {
    expect(secondaryLocationText('B2')).toBe('B2');
    expect(secondaryLocationText('  B2  ')).toBe('B2');
    expect(secondaryLocationText('')).toBe('N/A');
    expect(secondaryLocationText('   ')).toBe('N/A');
    expect(secondaryLocationText(undefined)).toBe('N/A');
  });
});
