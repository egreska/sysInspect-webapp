/**
 * Client-side PDF generator matching iOS app layout.
 * Landscape orientation with table columns:
 * Image | Primary Location | Importance | Issue | Comments
 */
import { jsPDF } from 'jspdf';
import { format } from 'date-fns';
import type { Inspection, InspectionItem } from '../types';

const PAGE_WIDTH = 792;   // 11" landscape
const PAGE_HEIGHT = 612;  // 8.5" landscape
const MARGIN = 36;
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;
const ROW_HEIGHT = 70;
const HEADER_ROW_HEIGHT = 28;
const FOOTER_HEIGHT = 30;

const COL_WIDTHS = [60, 120, 72, 200, CONTENT_WIDTH - 60 - 120 - 72 - 200];

function getHierarchicalIssues(item: InspectionItem): string[] {
  const issues: string[] = [];
  function add(parent: string, child?: string, grandchild?: string) {
    let s = parent;
    if (child) { s += ' > ' + child; if (grandchild) s += ' > ' + grandchild; }
    issues.push(s);
  }

  if (item.upright) {
    if (item.uprightFrontDamage) add('Upright', 'Front', 'Damage');
    if (item.uprightFrontTwisted) add('Upright', 'Front', 'Twisted');
    if (item.uprightRearDamage) add('Upright', 'Rear', 'Damage');
    if (item.uprightRearTwisted) add('Upright', 'Rear', 'Twisted');
    if (item.uprightAlignmentOutOfAlignment) add('Upright', 'Alignment', 'Out of alignment');
    if (item.uprightAlignmentOutOfVerticalPlumb) add('Upright', 'Alignment', 'Out of vertical plumb');
    if (!item.uprightFrontDamage && !item.uprightFrontTwisted && !item.uprightRearDamage &&
        !item.uprightRearTwisted && !item.uprightAlignmentOutOfAlignment &&
        !item.uprightAlignmentOutOfVerticalPlumb) add('Upright');
  }
  if (item.beam) {
    if (item.beamFrontDamage) add('Beam', 'Front damage');
    if (item.beamRearDamage) add('Beam', 'Rear damage');
    if (item.beamFrontBowed) add('Beam', 'Front bowed');
    if (item.beamRearBowed) add('Beam', 'Rear bowed');
    if (!item.beamFrontDamage && !item.beamRearDamage && !item.beamFrontBowed && !item.beamRearBowed) add('Beam');
  }
  if (item.wireDeck) {
    if (item.wireDeckMissing) add('Wire Deck', 'Missing');
    if (item.wireDeckDamaged) add('Wire Deck', 'Damaged');
    if (item.wireDeckOutOfPosition) add('Wire Deck', 'Out of position');
    if (!item.wireDeckMissing && !item.wireDeckDamaged && !item.wireDeckOutOfPosition) add('Wire Deck');
  }
  if (item.basePlate) {
    if (item.basePlateFloorDamaged) add('Base Plate', 'Floor damaged');
    if (item.basePlateTwisted) add('Base Plate', 'Twisted');
    if (item.basePlateDamaged) add('Base Plate', 'Damaged');
    if (!item.basePlateFloorDamaged && !item.basePlateTwisted && !item.basePlateDamaged) add('Base Plate');
  }
  if (item.anchors) {
    if (item.anchorsMissing) add('Anchors', 'Missing anchors or bolts');
    if (item.anchorsDamaged) add('Anchors', 'Damaged or bent');
    if (item.anchorsTorqued) add('Anchors', 'Torqued to 35lbs');
    if (!item.anchorsMissing && !item.anchorsDamaged && !item.anchorsTorqued) add('Anchors');
  }
  if (item.bracingDamage) {
    if (item.bracingHorizontal) add('Bracing', 'Horizontal');
    if (item.bracingDiagonal) add('Bracing', 'Diagonal');
    if (!item.bracingHorizontal && !item.bracingDiagonal) add('Bracing');
  }
  if (item.postProtector) {
    if (item.postProtectorMissing) add('Post Protector', 'Missing');
    if (item.postProtectorDamaged) add('Post Protector', 'Damaged');
    if (item.postProtectorRepairRequired) add('Post Protector', 'Repair required');
    if (!item.postProtectorMissing && !item.postProtectorDamaged && !item.postProtectorRepairRequired) add('Post Protector');
  }
  if (item.aisleGuarding) {
    if (item.aisleGuardingMissing) add('Aisle Guarding', 'Missing');
    if (item.aisleGuardingDamaged) add('Aisle Guarding', 'Damaged');
    if (item.aisleGuardingRepairRequired) add('Aisle Guarding', 'Repair required');
    if (!item.aisleGuardingMissing && !item.aisleGuardingDamaged && !item.aisleGuardingRepairRequired) add('Aisle Guarding');
  }
  return issues;
}

function drawTableHeader(doc: jsPDF, y: number): number {
  doc.setFillColor(230, 230, 230);
  doc.rect(MARGIN, y, CONTENT_WIDTH, HEADER_ROW_HEIGHT, 'F');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(0);

  const headers = ['Image', 'Primary\nLocation', 'Importance', 'Issue', 'Comments'];
  let x = MARGIN;
  for (let i = 0; i < headers.length; i++) {
    const lines = headers[i].split('\n');
    const lineH = 10;
    const startY = y + (HEADER_ROW_HEIGHT - lines.length * lineH) / 2 + 8;
    lines.forEach((line, li) => {
      doc.text(line, x + COL_WIDTHS[i] / 2, startY + li * lineH, { align: 'center' });
    });
    x += COL_WIDTHS[i];
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

export async function generatePDF(inspection: Inspection): Promise<Blob> {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'letter' });
  const items = inspection.items || [];

  // Pre-load all photo URLs as base64 for embedding in PDF
  const photoCache = new Map<string, string>();
  await Promise.all(
    items.map(async (item) => {
      if (item.photoUrl) {
        const b64 = await loadImageAsBase64(item.photoUrl);
        if (b64) photoCache.set(item.id, b64);
      }
    })
  );
  let y = MARGIN;

  // --- Header ---
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(20);
  doc.setTextColor(0);
  doc.text('Inspection Report', PAGE_WIDTH / 2, y + 20, { align: 'center' });
  y += 36;

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
  doc.text(`Inspector: ${inspector}`, MARGIN + 220, y);
  y += 20;

  // --- Table ---
  y = drawTableHeader(doc, y);

  const maxBottomY = PAGE_HEIGHT - MARGIN - FOOTER_HEIGHT;

  // Pre-calculate pages for footer numbering
  let tempY = y;
  let pageCount = 1;
  for (let i = 0; i < items.length; i++) {
    if (tempY + ROW_HEIGHT > maxBottomY) {
      pageCount++;
      tempY = MARGIN + HEADER_ROW_HEIGHT;
    }
    tempY += ROW_HEIGHT;
  }

  let currentPage = 1;

  items.forEach((item) => {
    if (y + ROW_HEIGHT > maxBottomY) {
      drawFooter(doc, currentPage, pageCount);
      doc.addPage();
      currentPage++;
      y = MARGIN;
      y = drawTableHeader(doc, y);
    }

    let x = MARGIN;

    // Column separators (light gray)
    doc.setDrawColor(200);
    doc.setLineWidth(0.3);
    let sepX = MARGIN;
    for (let c = 0; c < COL_WIDTHS.length - 1; c++) {
      sepX += COL_WIDTHS[c];
      doc.line(sepX, y, sepX, y + ROW_HEIGHT);
    }

    // Image column
    const imgW = COL_WIDTHS[0];
    const cachedImg = photoCache.get(item.id);
    const imgSrc = cachedImg || (item.photoData ? `data:image/jpeg;base64,${item.photoData}` : null);
    if (imgSrc) {
      try {
        const maxImgW = imgW - 10;
        const maxImgH = ROW_HEIGHT - 10;
        doc.addImage(imgSrc, 'JPEG', x + 5, y + 5, maxImgW, maxImgH);
      } catch {
        doc.setFontSize(7);
        doc.setFont('helvetica', 'italic');
        doc.text('No Photo', x + 5, y + ROW_HEIGHT / 2);
      }
    } else {
      doc.setFontSize(7);
      doc.setFont('helvetica', 'italic');
      doc.setTextColor(150);
      doc.text('No Photo', x + 5, y + ROW_HEIGHT / 2);
      doc.setTextColor(0);
    }
    x += imgW;

    // Primary Location
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    doc.setTextColor(0);
    const locW = COL_WIDTHS[1] - 10;
    const locLines = wrapText(doc, item.location || 'N/A', locW);
    doc.text(locLines, x + 5, y + 14);
    if (item.bayNumber) {
      doc.setFontSize(7);
      doc.setTextColor(100);
      doc.text(`Bay: ${item.bayNumber}`, x + 5, y + 14 + locLines.length * 10 + 2);
      doc.setTextColor(0);
    }
    x += COL_WIDTHS[1];

    // Importance
    const impW = COL_WIDTHS[2] - 10;
    const impStr = item.importance || 'Monitor';
    doc.setFontSize(8);
    if (impStr === 'Needs immediate attention') {
      doc.setTextColor(200, 0, 0);
      doc.setFont('helvetica', 'bold');
    } else {
      doc.setTextColor(0);
      doc.setFont('helvetica', 'normal');
    }
    const impLines = wrapText(doc, impStr, impW);
    doc.text(impLines, x + 5, y + 14);
    doc.setTextColor(0);
    doc.setFont('helvetica', 'normal');
    x += COL_WIDTHS[2];

    // Issue (hierarchical like iOS)
    const issueW = COL_WIDTHS[3] - 10;
    const issueStrings = getHierarchicalIssues(item);
    const issueText = issueStrings.length > 0 ? issueStrings.map(s => '\u2022 ' + s).join('\n') : 'No issues';
    doc.setFontSize(7);
    const issueLines = wrapText(doc, issueText, issueW);
    doc.text(issueLines.slice(0, 8), x + 5, y + 12);
    x += COL_WIDTHS[3];

    // Comments
    const commentW = COL_WIDTHS[4] - 10;
    doc.setFontSize(7);
    const commentLines = wrapText(doc, item.comments || '', commentW);
    doc.text(commentLines.slice(0, 8), x + 5, y + 12);

    // Row bottom border
    doc.setDrawColor(200);
    doc.setLineWidth(0.3);
    doc.line(MARGIN, y + ROW_HEIGHT, MARGIN + CONTENT_WIDTH, y + ROW_HEIGHT);

    y += ROW_HEIGHT;
  });

  // Draw footer on final page
  drawFooter(doc, currentPage, pageCount);

  return doc.output('blob');
}
