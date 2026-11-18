/** Columns and widths for one web inspection report. The generator draws this list. */

export type PdfColumnKind =
  | 'image'
  | 'primaryLocation'
  | 'secondaryLocation'
  | 'importance'
  | 'issue'
  | 'comments';

export interface PdfColumn {
  kind: PdfColumnKind;
  width: number;
  header: string;
}

export interface PdfLayoutItem {
  photoCount: number;
  bayNumber?: string;
  comments?: string;
}

const IMAGE_WIDTH = 60;
const PRIMARY_WIDTH = 120;
const IMPORTANCE_WIDTH = 72;
const SECONDARY_WIDTH = 72;
const ISSUE_WIDTH_WITH_COMMENTS = 200;

function hasText(value: string | undefined): boolean {
  return !!value && value.trim().length > 0;
}

export function secondaryLocationText(bayNumber: string | undefined): string {
  const bay = bayNumber?.trim();
  return bay ? bay : 'N/A';
}

export function resolvePdfTableLayout(items: PdfLayoutItem[], contentWidth: number): PdfColumn[] {
  const includeImage = items.some((item) => item.photoCount > 0);
  const includeSecondary = items.some((item) => hasText(item.bayNumber));
  const includeComments = items.some((item) => hasText(item.comments));

  const columns: PdfColumn[] = [];
  if (includeImage) columns.push({ kind: 'image', width: IMAGE_WIDTH, header: 'Image' });
  columns.push({ kind: 'primaryLocation', width: PRIMARY_WIDTH, header: 'Primary\nLocation' });
  if (includeSecondary) {
    columns.push({ kind: 'secondaryLocation', width: SECONDARY_WIDTH, header: 'Secondary\nLocation' });
  }
  columns.push({ kind: 'importance', width: IMPORTANCE_WIDTH, header: 'Importance' });

  const fixed = columns.reduce((sum, column) => sum + column.width, 0);
  const remaining = contentWidth - fixed;
  if (includeComments) {
    columns.push({ kind: 'issue', width: ISSUE_WIDTH_WITH_COMMENTS, header: 'Issue' });
    columns.push({ kind: 'comments', width: remaining - ISSUE_WIDTH_WITH_COMMENTS, header: 'Comments' });
  } else {
    columns.push({ kind: 'issue', width: remaining, header: 'Issue' });
  }
  return columns;
}
