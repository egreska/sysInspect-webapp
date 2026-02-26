/**
 * Client-side PDF generator using jsPDF.
 * Generates inspection reports from CloudKit data.
 */
import { jsPDF } from 'jspdf';
import { format } from 'date-fns';
import type { Inspection, InspectionItem } from '../types';

const MARGIN = 50;
const PAGE_WIDTH = 612; // Letter
const PAGE_HEIGHT = 792;

function getDamagesList(item: InspectionItem): string[] {
  const damages: string[] = [];
  if (item.uprightFrontDamage) damages.push('Upright Front Damage');
  if (item.uprightFrontTwisted) damages.push('Upright Front Twisted');
  if (item.uprightRearDamage) damages.push('Upright Rear Damage');
  if (item.uprightRearTwisted) damages.push('Upright Rear Twisted');
  if (item.uprightAlignmentOutOfAlignment) damages.push('Out of Alignment');
  if (item.uprightAlignmentOutOfVerticalPlumb) damages.push('Out of Vertical Plumb');
  if (item.beamFrontDamage) damages.push('Beam Front Damage');
  if (item.beamFrontBowed) damages.push('Beam Front Bowed');
  if (item.beamRearDamage) damages.push('Beam Rear Damage');
  if (item.beamRearBowed) damages.push('Beam Rear Bowed');
  if (item.bracingDamage) damages.push('Bracing Damage');
  if (item.basePlateDamaged) damages.push('Base Plate Damaged');
  if (item.basePlateTwisted) damages.push('Base Plate Twisted');
  if (item.basePlateFloorDamaged) damages.push('Floor Damaged');
  if (item.anchorsDamaged) damages.push('Anchors Damaged');
  if (item.anchorsMissing) damages.push('Anchors Missing');
  if (item.wireDeckDamaged) damages.push('Wire Deck Damaged');
  if (item.wireDeckMissing) damages.push('Wire Deck Missing');
  if (item.wireDeckOutOfPosition) damages.push('Wire Deck Out of Position');
  if (item.postProtectorDamaged) damages.push('Post Protector Damaged');
  if (item.postProtectorMissing) damages.push('Post Protector Missing');
  if (item.postProtectorRepairRequired) damages.push('Post Protector Repair Required');
  if (item.aisleGuardingDamaged) damages.push('Aisle Guarding Damaged');
  if (item.aisleGuardingMissing) damages.push('Aisle Guarding Missing');
  if (item.aisleGuardingRepairRequired) damages.push('Aisle Guarding Repair Required');
  return damages;
}

export function generatePDF(inspection: Inspection, company = 'Systems Inspector'): Blob {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'pt', format: 'letter' });
  let y = MARGIN;

  // Header
  doc.setFontSize(20);
  doc.setFont('helvetica', 'bold');
  doc.text('INSPECTION REPORT', PAGE_WIDTH / 2, y, { align: 'center' });
  y += 24;

  doc.setFontSize(12);
  doc.setFont('helvetica', 'normal');
  doc.text(company, PAGE_WIDTH / 2, y, { align: 'center' });
  y += 16;

  const dateStr = inspection.date
    ? format(new Date(inspection.date), 'MMMM dd, yyyy')
    : format(new Date(), 'MMMM dd, yyyy');
  doc.setFontSize(10);
  doc.text(`Inspection Date: ${dateStr}`, PAGE_WIDTH / 2, y, { align: 'center' });
  y += 14;
  if (inspection.inspectorName) {
    doc.text(`Inspector: ${inspection.inspectorName}`, PAGE_WIDTH / 2, y, { align: 'center' });
    y += 14;
  }
  y += 10;
  doc.setDrawColor(200);
  doc.line(MARGIN, y, PAGE_WIDTH - MARGIN, y);
  y += 20;

  // Customer info
  if (inspection.customer) {
    doc.setFontSize(14);
    doc.setFont('helvetica', 'bold');
    doc.text('CUSTOMER INFORMATION', MARGIN, y);
    y += 20;
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    if (inspection.customer.name) {
      doc.text(`Company: ${inspection.customer.name}`, MARGIN, y);
      y += 14;
    }
    if (inspection.customer.contactName) {
      doc.text(`Contact: ${inspection.customer.contactName}`, MARGIN, y);
      y += 14;
    }
    if (inspection.customer.phone) {
      doc.text(`Phone: ${inspection.customer.phone}`, MARGIN, y);
      y += 14;
    }
    const addr = [inspection.customer.address, inspection.customer.city, inspection.customer.state, inspection.customer.zipCode]
      .filter(Boolean)
      .join(', ');
    if (addr) {
      doc.text(`Address: ${addr}`, MARGIN, y);
      y += 14;
    }
    if (inspection.customer.site) {
      doc.text(`Site: ${inspection.customer.site}`, MARGIN, y);
      y += 14;
    }
    y += 10;
    doc.line(MARGIN, y, PAGE_WIDTH - MARGIN, y);
    y += 20;
  }

  // Summary
  const items = inspection.items || [];
  const critical = items.filter((i) => i.importance === 'Critical').length;
  const repair = items.filter((i) => i.importance === 'Repair').length;
  const monitor = items.filter((i) => i.importance === 'Monitor').length;

  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('INSPECTION SUMMARY', MARGIN, y);
  y += 20;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`Total Inspection Points: ${items.length}`, MARGIN, y);
  y += 14;
  doc.text(`Critical Issues: ${critical}`, MARGIN, y);
  y += 14;
  doc.text(`Repair Required: ${repair}`, MARGIN, y);
  y += 14;
  doc.text(`Monitor: ${monitor}`, MARGIN, y);
  y += 20;
  doc.line(MARGIN, y, PAGE_WIDTH - MARGIN, y);
  y += 20;

  // Inspection items
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('INSPECTION ITEMS', MARGIN, y);
  y += 24;

  items.forEach((item, idx) => {
    if (y > PAGE_HEIGHT - 120) {
      doc.addPage();
      y = MARGIN;
    }

    doc.setFontSize(12);
    doc.setFont('helvetica', 'bold');
    doc.text(`Item ${idx + 1}: ${item.location || 'No location'}`, MARGIN, y);
    y += 16;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
    if (item.bayNumber) {
      doc.text(`Bay Number: ${item.bayNumber}`, MARGIN, y);
      y += 14;
    }
    doc.text(`Status: ${item.importance || 'Monitor'}`, MARGIN, y);
    y += 14;

    const damages = getDamagesList(item);
    if (damages.length > 0) {
      doc.text('Damage Components:', MARGIN, y);
      y += 14;
      damages.forEach((d) => {
        doc.text(`  • ${d}`, MARGIN + 10, y);
        y += 12;
      });
    }

    if (item.comments) {
      doc.text(`Comments: ${item.comments}`, MARGIN, y);
      y += 14;
    }

    if (item.photoData && y < PAGE_HEIGHT - 220) {
      try {
        doc.addImage(`data:image/jpeg;base64,${item.photoData}`, 'JPEG', MARGIN, y, 150, 100);
        y += 110;
      } catch {
        y += 14;
      }
    }

    y += 16;
    if (idx < items.length - 1) {
      doc.setDrawColor(220);
      doc.line(MARGIN, y, PAGE_WIDTH - MARGIN, y);
      y += 16;
    }
  });

  // Footer
  const pageCount = doc.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    doc.text(
      `Page ${i} of ${pageCount} - Generated by Systems Inspector - ${format(new Date(), 'MM/dd/yyyy')}`,
      PAGE_WIDTH / 2,
      PAGE_HEIGHT - 30,
      { align: 'center' }
    );
  }

  return doc.output('blob');
}
