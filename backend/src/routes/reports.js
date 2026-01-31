import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import cloudkit from '../services/cloudkit.js';
import pdfGenerator from '../services/pdfGenerator.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * GET /api/reports/inspection/:id
 * Generate PDF report for an inspection
 */
router.get('/inspection/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    
    // Fetch complete inspection data
    const inspection = await cloudkit.fetchRecord(id, 'Inspection');

    if (!inspection) {
      return res.status(404).json({ error: 'Inspection not found' });
    }

    // Verify ownership
    if (inspection.fields.userId?.value !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Fetch inspection items
    const items = await cloudkit.fetchInspectionItems(id);

    // Fetch customer info
    const customerRef = inspection.fields.customer?.value;
    let customer = null;
    if (customerRef && customerRef.recordName) {
      customer = await cloudkit.fetchRecord(customerRef.recordName, 'Customer');
    }

    // Prepare inspection data
    const inspectionData = {
      id: inspection.recordName,
      date: inspection.fields.date?.value,
      inspectorName: inspection.fields.inspectorName?.value || '',
      customer: customer ? {
        name: customer.fields.name?.value || '',
        contactName: customer.fields.contactName?.value || '',
        phone: customer.fields.phone?.value || '',
        address: customer.fields.address?.value || '',
        city: customer.fields.city?.value || '',
        state: customer.fields.state?.value || '',
        zipCode: customer.fields.zipCode?.value || '',
        site: customer.fields.site?.value || ''
      } : null,
      items: await Promise.all(items.map(async (item) => {
        // Download photo if exists
        let photoData = null;
        if (item.fields.photoURL?.value && item.fields.photoURL.value.downloadURL) {
          photoData = await cloudkit.downloadAsset(item.fields.photoURL.value.downloadURL);
        }

        return {
          location: item.fields.location?.value || '',
          bayNumber: item.fields.bayNumber?.value || '',
          importance: item.fields.importance?.value || 'Monitor',
          comments: item.fields.comments?.value || '',
          sequenceNumber: item.fields.sequenceNumber?.value || 0,
          photoData,
          // All damage components
          upright: item.fields.upright?.value || false,
          uprightFrontDamage: item.fields.uprightFrontDamage?.value || false,
          uprightFrontTwisted: item.fields.uprightFrontTwisted?.value || false,
          uprightRearDamage: item.fields.uprightRearDamage?.value || false,
          uprightRearTwisted: item.fields.uprightRearTwisted?.value || false,
          uprightAlignmentOutOfAlignment: item.fields.uprightAlignmentOutOfAlignment?.value || false,
          uprightAlignmentOutOfVerticalPlumb: item.fields.uprightAlignmentOutOfVerticalPlumb?.value || false,
          beam: item.fields.beam?.value || false,
          beamFrontDamage: item.fields.beamFrontDamage?.value || false,
          beamFrontBowed: item.fields.beamFrontBowed?.value || false,
          beamRearDamage: item.fields.beamRearDamage?.value || false,
          beamRearBowed: item.fields.beamRearBowed?.value || false,
          bracingDiagonal: item.fields.bracingDiagonal?.value || false,
          bracingHorizontal: item.fields.bracingHorizontal?.value || false,
          bracingDamage: item.fields.bracingDamage?.value || false,
          basePlate: item.fields.basePlate?.value || false,
          basePlateDamaged: item.fields.basePlateDamaged?.value || false,
          basePlateTwisted: item.fields.basePlateTwisted?.value || false,
          basePlateFloorDamaged: item.fields.basePlateFloorDamaged?.value || false,
          anchors: item.fields.anchors?.value || false,
          anchorsDamaged: item.fields.anchorsDamaged?.value || false,
          anchorsMissing: item.fields.anchorsMissing?.value || false,
          anchorsTorqued: item.fields.anchorsTorqued?.value || false,
          wireDeck: item.fields.wireDeck?.value || false,
          wireDeckDamaged: item.fields.wireDeckDamaged?.value || false,
          wireDeckMissing: item.fields.wireDeckMissing?.value || false,
          wireDeckOutOfPosition: item.fields.wireDeckOutOfPosition?.value || false,
          postProtector: item.fields.postProtector?.value || false,
          postProtectorDamaged: item.fields.postProtectorDamaged?.value || false,
          postProtectorMissing: item.fields.postProtectorMissing?.value || false,
          postProtectorRepairRequired: item.fields.postProtectorRepairRequired?.value || false,
          aisleGuarding: item.fields.aisleGuarding?.value || false,
          aisleGuardingDamaged: item.fields.aisleGuardingDamaged?.value || false,
          aisleGuardingMissing: item.fields.aisleGuardingMissing?.value || false,
          aisleGuardingRepairRequired: item.fields.aisleGuardingRepairRequired?.value || false
        };
      }))
    };

    // Sort items by sequence number
    inspectionData.items.sort((a, b) => a.sequenceNumber - b.sequenceNumber);

    // Generate PDF
    const pdf = pdfGenerator.generateReport(inspectionData);

    // Set response headers
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename=inspection-report-${id}.pdf`
    );

    // Pipe PDF to response
    pdf.pipe(res);
  } catch (error) {
    next(error);
  }
});

export default router;
