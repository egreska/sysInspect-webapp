/**
 * Client-side PDF generator. Table columns and widths come from pdfTableLayout.
 */
import { jsPDF } from 'jspdf';
import { format } from 'date-fns';
import { importancePhrase, isImmediate } from '../importance';
import type { Inspection, InspectionItem } from '../types';
import { Issue } from '../issue';
import { LIST_STOPPED_EARLY } from './load';
import { resolvePdfTableLayout, secondaryLocationText, type PdfColumn } from './pdfTableLayout';

const PAGE_WIDTH = 792;   // 11" landscape
const PAGE_HEIGHT = 612;  // 8.5" landscape
const MARGIN = 36;
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;
const ROW_HEIGHT = 70;
const EXTRA_PHOTO_STRIP = 72;
const HEADER_ROW_HEIGHT = 28;
const FOOTER_HEIGHT = 30;

function drawTableHeader(doc: jsPDF, y: number, columns: PdfColumn[]): number {
  doc.setFillColor(230, 230, 230);
  doc.rect(MARGIN, y, CONTENT_WIDTH, HEADER_ROW_HEIGHT, 'F');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(0);

  let x = MARGIN;
  for (const column of columns) {
    const lines = column.header.split('\n');
    const lineH = 10;
    const startY = y + (HEADER_ROW_HEIGHT - lines.length * lineH) / 2 + 8;
    lines.forEach((line, li) => {
      doc.text(line, x + column.width / 2, startY + li * lineH, { align: 'center' });
    });
    x += column.width;
  }

  doc.setDrawColor(0);
  doc.setLineWidth(0.5);
  doc.line(MARGIN, y + HEADER_ROW_HEIGHT, MARGIN + CONTENT_WIDTH, y + HEADER_ROW_HEIGHT);

  return y + HEADER_ROW_HEIGHT;
}

function drawFooter(doc: jsPDF, page: number, totalPages: number) {
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(128);
  const footerY = PAGE_HEIGHT - MARGIN + 10;
  doc.text(
    `Page ${page} of ${totalPages}`,
    PAGE_WIDTH - MARGIN,
    footerY,
    { align: 'right' }
  );
  doc.text('Systems Inspector', MARGIN, footerY);
}

function wrapText(doc: jsPDF, text: string, maxWidth: number): string[] {
  if (!text) return [];
  return doc.splitTextToSize(text, maxWidth) as string[];
}

async function loadImageAsBase64(url: string): Promise<string | null> {
  try {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error('Image load failed'));
      img.src = url;
    });
    const canvas = document.createElement('canvas');
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;
    ctx.drawImage(img, 0, 0);
    return canvas.toDataURL('image/jpeg', 0.7);
  } catch {
    return null;
  }
}

function itemRowHeight(item: InspectionItem): number {
  return ROW_HEIGHT + ((item.photoUrls?.length ?? 0) > 1 ? EXTRA_PHOTO_STRIP : 0);
}

function issueText(item: InspectionItem): string {
  const labels = Issue.labels(item.issues);
  return labels.length > 0 ? labels.join('\n') : 'No issues';
}

function drawWrappedCell(doc: jsPDF, text: string, x: number, y: number, width: number) {
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(0);
  doc.text(wrapText(doc, text, width - 10).slice(0, 8), x + 5, y + 12);
}

function drawImportanceCell(doc: jsPDF, item: InspectionItem, x: number, y: number, width: number) {
  doc.setFontSize(8);
  if (isImmediate(item.importance)) {
    doc.setTextColor(200, 0, 0);
    doc.setFont('helvetica', 'bold');
  } else {
    doc.setTextColor(0);
    doc.setFont('helvetica', 'normal');
  }
  doc.text(wrapText(doc, importancePhrase(item.importance), width - 10), x + 5, y + 14);
  doc.setTextColor(0);
  doc.setFont('helvetica', 'normal');
}

function drawImageCell(doc: jsPDF, src: string | undefined, x: number, y: number, width: number) {
  if (src) {
    try {
      doc.addImage(src, 'JPEG', x + 5, y + 5, width - 10, ROW_HEIGHT - 10);
      return;
    } catch {
      /* fall through to the missing-photo label */
    }
  }
  doc.setFontSize(7);
  doc.setFont('helvetica', 'italic');
  doc.setTextColor(150);
  doc.text('No Photo', x + 5, y + ROW_HEIGHT / 2);
  doc.setTextColor(0);
}

export async function generatePDF(inspection: Inspection): Promise<Blob> {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'letter' });
  const items = inspection.items || [];
  const columns = resolvePdfTableLayout(
    items.map((item) => ({
      photoCount: item.photoUrls?.length ?? 0,
      bayNumber: item.bayNumber,
      comments: item.comments,
    })),
    CONTENT_WIDTH
  );

  // Pre-load all photo URLs as base64 for embedding in PDF
  const photoCache = new Map<string, string[]>();
  await Promise.all(
    items.map(async (item) => {
      const urls = item.photoUrls || [];
      const encoded = await Promise.all(urls.map((url) => loadImageAsBase64(url)));
      photoCache.set(item.id, encoded.filter((b64): b64 is string => !!b64));
    })
  );
  let y = MARGIN;

  // --- Header ---
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(20);
  doc.setTextColor(0);
  doc.text('Inspection Report', PAGE_WIDTH / 2, y + 20, { align: 'center' });
  y += 36;
  if (inspection.itemsStoppedEarly) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
    doc.setTextColor(180, 80, 0);
    doc.text(LIST_STOPPED_EARLY, MARGIN, y);
    y += 16;
    doc.setTextColor(0);
  }

  // --- Customer info row ---
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('Customer Information', MARGIN, y);
  y += 2;
  doc.setDrawColor(180);
  doc.setLineWidth(0.3);
  doc.line(MARGIN, y, MARGIN + CONTENT_WIDTH, y);
  y += 12;

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  const customerName = inspection.customer?.name || 'N/A';
  const addr = [inspection.customer?.address, inspection.customer?.city, inspection.customer?.state, inspection.customer?.zipCode].filter(Boolean).join(', ');
  const dateStr = inspection.date ? format(new Date(inspection.date), 'MMMM dd, yyyy') : 'N/A';
  const inspector = inspection.inspectorName || 'N/A';

  doc.text(`Customer: ${customerName}`, MARGIN, y);
  doc.text(`Address: ${addr || 'N/A'}`, MARGIN + 220, y);
  y += 13;
  doc.text(`Date: ${dateStr}`, MARGIN, y);
  doc.text(`Inspector Name: ${inspector}`, MARGIN + 220, y);
  y += 20;

  // --- Table ---
  y = drawTableHeader(doc, y, columns);

  const maxBottomY = PAGE_HEIGHT - MARGIN - FOOTER_HEIGHT;

  // Pre-calculate pages for footer numbering
  let tempY = y;
  let pageCount = 1;
  for (let i = 0; i < items.length; i++) {
    const h = itemRowHeight(items[i]);
    if (tempY + h > maxBottomY) {
      pageCount++;
      tempY = MARGIN + HEADER_ROW_HEIGHT;
    }
    tempY += h;
  }

  let currentPage = 1;

  items.forEach((item) => {
    const rowH = itemRowHeight(item);
    if (y + rowH > maxBottomY) {
      drawFooter(doc, currentPage, pageCount);
      doc.addPage();
      currentPage++;
      y = MARGIN;
      y = drawTableHeader(doc, y, columns);
    }

    let x = MARGIN;

    // Column separators (light gray)
    doc.setDrawColor(200);
    doc.setLineWidth(0.3);
    let sepX = MARGIN;
    for (let c = 0; c < columns.length - 1; c++) {
      sepX += columns[c].width;
      doc.line(sepX, y, sepX, y + ROW_HEIGHT);
    }

    const cached = photoCache.get(item.id) || [];
    for (const column of columns) {
      switch (column.kind) {
        case 'image':
          drawImageCell(doc, cached[0], x, y, column.width);
          break;
        case 'primaryLocation':
          doc.setFont('helvetica', 'normal');
          doc.setFontSize(8);
          doc.setTextColor(0);
          doc.text(wrapText(doc, item.location || 'N/A', column.width - 10), x + 5, y + 14);
          break;
        case 'secondaryLocation':
          doc.setFont('helvetica', 'normal');
          doc.setFontSize(8);
          doc.setTextColor(0);
          doc.text(secondaryLocationText(item.bayNumber), x + 5, y + 14);
          break;
        case 'importance':
          drawImportanceCell(doc, item, x, y, column.width);
          break;
        case 'issue':
          drawWrappedCell(doc, issueText(item), x, y, column.width);
          break;
        case 'comments':
          drawWrappedCell(doc, item.comments || '', x, y, column.width);
          break;
      }
      x += column.width;
    }

    // Row bottom border
    doc.setDrawColor(200);
    doc.setLineWidth(0.3);
    doc.line(MARGIN, y + ROW_HEIGHT, MARGIN + CONTENT_WIDTH, y + ROW_HEIGHT);

    if (cached.length > 1) {
      let extraX = MARGIN;
      cached.slice(1).forEach((src) => {
        try {
          doc.addImage(src, 'JPEG', extraX, y + ROW_HEIGHT + 6, 60, 60);
        } catch {
          /* skip unloadable extra */
        }
        extraX += 68;
      });
    }

    y += rowH;
  });

  // Draw footer on final page
  drawFooter(doc, currentPage, pageCount);

  return doc.output('blob');
}
