import PDFDocument from 'pdfkit';
import { format } from 'date-fns';

/**
 * PDF Generator Service
 * Generates inspection reports matching the iOS app format
 */
class PDFGeneratorService {
  /**
   * Generate inspection report PDF
   */
  generateReport(inspection, inspectorCompany = 'Systems Inspector') {
    const doc = new PDFDocument({ size: 'LETTER', margin: 50 });
    
    // Header
    this.addHeader(doc, inspection, inspectorCompany);
    
    // Customer Information
    this.addCustomerInfo(doc, inspection.customer);
    
    // Inspection Details
    this.addInspectionDetails(doc, inspection);
    
    // Inspection Items
    this.addInspectionItems(doc, inspection.items);
    
    // Footer on each page
    this.addFooter(doc);
    
    doc.end();
    return doc;
  }

  /**
   * Add header to PDF
   */
  addHeader(doc, inspection, company) {
    doc.fontSize(20)
       .font('Helvetica-Bold')
       .text('INSPECTION REPORT', { align: 'center' });
    
    doc.moveDown(0.5);
    
    doc.fontSize(12)
       .font('Helvetica')
       .text(company, { align: 'center' });
    
    doc.moveDown(0.5);
    
    const dateStr = inspection.date 
      ? format(new Date(inspection.date), 'MMMM dd, yyyy')
      : format(new Date(), 'MMMM dd, yyyy');
    
    doc.fontSize(10)
       .text(`Inspection Date: ${dateStr}`, { align: 'center' });
    
    if (inspection.inspectorName) {
      doc.text(`Inspector: ${inspection.inspectorName}`, { align: 'center' });
    }
    
    doc.moveDown(1);
    doc.moveTo(50, doc.y).lineTo(562, doc.y).stroke();
    doc.moveDown(1);
  }

  /**
   * Add customer information section
   */
  addCustomerInfo(doc, customer) {
    if (!customer) return;
    
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .text('CUSTOMER INFORMATION');
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .font('Helvetica');
    
    if (customer.name) {
      doc.text(`Company: ${customer.name}`);
    }
    
    if (customer.contactName) {
      doc.text(`Contact: ${customer.contactName}`);
    }
    
    if (customer.phone) {
      doc.text(`Phone: ${customer.phone}`);
    }
    
    if (customer.address || customer.city || customer.state || customer.zipCode) {
      const addressParts = [
        customer.address,
        customer.city,
        customer.state,
        customer.zipCode
      ].filter(Boolean);
      doc.text(`Address: ${addressParts.join(', ')}`);
    }
    
    if (customer.site) {
      doc.text(`Site: ${customer.site}`);
    }
    
    doc.moveDown(1);
    doc.moveTo(50, doc.y).lineTo(562, doc.y).stroke();
    doc.moveDown(1);
  }

  /**
   * Add inspection details
   */
  addInspectionDetails(doc, inspection) {
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .text('INSPECTION SUMMARY');
    
    doc.moveDown(0.5);
    
    doc.fontSize(10)
       .font('Helvetica');
    
    const totalItems = inspection.items.length;
    const criticalItems = inspection.items.filter(item => item.importance === 'Critical').length;
    const repairItems = inspection.items.filter(item => item.importance === 'Repair').length;
    const monitorItems = inspection.items.filter(item => item.importance === 'Monitor').length;
    
    doc.text(`Total Inspection Points: ${totalItems}`);
    doc.text(`Critical Issues: ${criticalItems}`, { continued: true });
    doc.fillColor('red').text(criticalItems > 0 ? ' ⚠' : '', { continued: false }).fillColor('black');
    doc.text(`Repair Required: ${repairItems}`);
    doc.text(`Monitor: ${monitorItems}`);
    
    doc.moveDown(1);
    doc.moveTo(50, doc.y).lineTo(562, doc.y).stroke();
    doc.moveDown(1);
  }

  /**
   * Add inspection items
   */
  addInspectionItems(doc, items) {
    doc.fontSize(14)
       .font('Helvetica-Bold')
       .text('INSPECTION ITEMS');
    
    doc.moveDown(0.5);
    
    items.forEach((item, index) => {
      // Check if we need a new page
      if (doc.y > 650) {
        doc.addPage();
      }
      
      doc.fontSize(12)
         .font('Helvetica-Bold')
         .text(`Item ${index + 1}:`, { continued: true })
         .font('Helvetica')
         .text(` ${item.location || 'No location specified'}`);
      
      doc.fontSize(10);
      
      if (item.bayNumber) {
        doc.text(`Bay Number: ${item.bayNumber}`);
      }
      
      // Importance level with color
      const importanceColor = {
        'Critical': 'red',
        'Repair': 'orange',
        'Monitor': 'blue'
      }[item.importance] || 'black';
      
      doc.text('Status: ', { continued: true })
         .fillColor(importanceColor)
         .text(item.importance || 'Monitor')
         .fillColor('black');
      
      // Damage components
      const damages = this.getDamagesList(item);
      if (damages.length > 0) {
        doc.text('Damage Components:');
        damages.forEach(damage => {
          doc.text(`  • ${damage}`, { indent: 10 });
        });
      }
      
      if (item.comments) {
        doc.text('Comments: ', { continued: true })
           .font('Helvetica-Oblique')
           .text(item.comments)
           .font('Helvetica');
      }
      
      // Add photo if exists
      if (item.photoData) {
        doc.moveDown(0.5);
        try {
          const imgBuffer = Buffer.from(item.photoData, 'base64');
          doc.image(imgBuffer, {
            fit: [200, 200],
            align: 'center'
          });
        } catch (error) {
          doc.text('[Photo unavailable]', { align: 'center', color: 'gray' });
        }
      }
      
      doc.moveDown(1);
      
      // Separator line
      if (index < items.length - 1) {
        doc.moveTo(50, doc.y).lineTo(562, doc.y).stroke('#cccccc');
        doc.moveDown(0.5);
      }
    });
  }

  /**
   * Get list of damages from inspection item
   */
  getDamagesList(item) {
    const damages = [];
    
    // Upright damages
    if (item.upright) {
      if (item.uprightFrontDamage) damages.push('Upright Front Damage');
      if (item.uprightFrontTwisted) damages.push('Upright Front Twisted');
      if (item.uprightRearDamage) damages.push('Upright Rear Damage');
      if (item.uprightRearTwisted) damages.push('Upright Rear Twisted');
      if (item.uprightAlignmentOutOfAlignment) damages.push('Out of Alignment');
      if (item.uprightAlignmentOutOfVerticalPlumb) damages.push('Out of Vertical Plumb');
    }
    
    // Beam damages
    if (item.beam) {
      if (item.beamFrontDamage) damages.push('Beam Front Damage');
      if (item.beamFrontBowed) damages.push('Beam Front Bowed');
      if (item.beamRearDamage) damages.push('Beam Rear Damage');
      if (item.beamRearBowed) damages.push('Beam Rear Bowed');
    }
    
    // Bracing damages
    if (item.bracingDiagonal && item.bracingDamage) damages.push('Diagonal Bracing Damage');
    if (item.bracingHorizontal && item.bracingDamage) damages.push('Horizontal Bracing Damage');
    
    // Base plate damages
    if (item.basePlate) {
      if (item.basePlateDamaged) damages.push('Base Plate Damaged');
      if (item.basePlateTwisted) damages.push('Base Plate Twisted');
      if (item.basePlateFloorDamaged) damages.push('Floor Damaged');
    }
    
    // Anchor damages
    if (item.anchors) {
      if (item.anchorsDamaged) damages.push('Anchors Damaged');
      if (item.anchorsMissing) damages.push('Anchors Missing');
      if (!item.anchorsTorqued) damages.push('Anchors Not Torqued');
    }
    
    // Wire deck damages
    if (item.wireDeck) {
      if (item.wireDeckDamaged) damages.push('Wire Deck Damaged');
      if (item.wireDeckMissing) damages.push('Wire Deck Missing');
      if (item.wireDeckOutOfPosition) damages.push('Wire Deck Out of Position');
    }
    
    // Post protector damages
    if (item.postProtector) {
      if (item.postProtectorDamaged) damages.push('Post Protector Damaged');
      if (item.postProtectorMissing) damages.push('Post Protector Missing');
      if (item.postProtectorRepairRequired) damages.push('Post Protector Repair Required');
    }
    
    // Aisle guarding damages
    if (item.aisleGuarding) {
      if (item.aisleGuardingDamaged) damages.push('Aisle Guarding Damaged');
      if (item.aisleGuardingMissing) damages.push('Aisle Guarding Missing');
      if (item.aisleGuardingRepairRequired) damages.push('Aisle Guarding Repair Required');
    }
    
    return damages;
  }

  /**
   * Add footer
   */
  addFooter(doc) {
    const pageCount = doc.bufferedPageRange().count;
    
    for (let i = 0; i < pageCount; i++) {
      doc.switchToPage(i);
      
      doc.fontSize(8)
         .font('Helvetica')
         .text(
           `Page ${i + 1} of ${pageCount}`,
           50,
           doc.page.height - 50,
           { align: 'center' }
         );
      
      doc.text(
        `Generated by Systems Inspector Web - ${format(new Date(), 'MM/dd/yyyy')}`,
        50,
        doc.page.height - 35,
        { align: 'center', color: 'gray' }
      );
    }
  }
}

export default new PDFGeneratorService();
