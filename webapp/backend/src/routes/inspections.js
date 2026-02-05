import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import cloudkit from '../services/cloudkit.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * GET /api/inspections/:id
 * Fetch a single inspection with all items
 */
router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    
    // Fetch inspection (Core Data + CloudKit uses CD_ prefix)
    const inspection = await cloudkit.fetchRecord(id, 'CD_Inspection');

    if (!inspection) {
      return res.status(404).json({ error: 'Inspection not found' });
    }

    // Verify ownership
    if (inspection.fields.CD_userId?.value !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Fetch inspection items
    const items = await cloudkit.fetchInspectionItems(id);

    // Fetch customer info
    const customerRef = inspection.fields.CD_customer?.value;
    let customer = null;
    if (customerRef && customerRef.recordName) {
      customer = await cloudkit.fetchRecord(customerRef.recordName, 'CD_Customer');
    }

    const transformedInspection = {
      id: inspection.recordName,
      date: inspection.fields.CD_date?.value,
      inspectorName: inspection.fields.CD_inspectorName?.value || '',
      customer: customer ? {
        id: customer.recordName,
        name: customer.fields.CD_name?.value || '',
        contactName: customer.fields.CD_contactName?.value || '',
        phone: customer.fields.CD_phone?.value || '',
        address: customer.fields.CD_address?.value || '',
        city: customer.fields.CD_city?.value || '',
        state: customer.fields.CD_state?.value || '',
        zipCode: customer.fields.CD_zipCode?.value || '',
        site: customer.fields.CD_site?.value || ''
      } : null,
      items: await Promise.all(items.map(async (item) => {
        // Download photo if exists (Core Data + CloudKit uses CD_ prefix)
        let photoData = null;
        if (item.fields.CD_photoURL?.value && item.fields.CD_photoURL.value.downloadURL) {
          photoData = await cloudkit.downloadAsset(item.fields.CD_photoURL.value.downloadURL);
        }

        return {
          id: item.recordName,
          location: item.fields.CD_location?.value || '',
          bayNumber: item.fields.CD_bayNumber?.value || '',
          importance: item.fields.CD_importance?.value || 'Monitor',
          comments: item.fields.CD_comments?.value || '',
          sequenceNumber: item.fields.CD_sequenceNumber?.value || 0,
          photoData,
          // Damage components
          upright: item.fields.CD_upright?.value || false,
          uprightFrontDamage: item.fields.CD_uprightFrontDamage?.value || false,
          uprightFrontTwisted: item.fields.CD_uprightFrontTwisted?.value || false,
          uprightRearDamage: item.fields.CD_uprightRearDamage?.value || false,
          uprightRearTwisted: item.fields.CD_uprightRearTwisted?.value || false,
          uprightAlignmentOutOfAlignment: item.fields.CD_uprightAlignmentOutOfAlignment?.value || false,
          uprightAlignmentOutOfVerticalPlumb: item.fields.CD_uprightAlignmentOutOfVerticalPlumb?.value || false,
          beam: item.fields.CD_beam?.value || false,
          beamFrontDamage: item.fields.CD_beamFrontDamage?.value || false,
          beamFrontBowed: item.fields.CD_beamFrontBowed?.value || false,
          beamRearDamage: item.fields.CD_beamRearDamage?.value || false,
          beamRearBowed: item.fields.CD_beamRearBowed?.value || false,
          bracingDiagonal: item.fields.CD_bracingDiagonal?.value || false,
          bracingHorizontal: item.fields.CD_bracingHorizontal?.value || false,
          bracingDamage: item.fields.CD_bracingDamage?.value || false,
          basePlate: item.fields.CD_basePlate?.value || false,
          basePlateDamaged: item.fields.CD_basePlateDamaged?.value || false,
          basePlateTwisted: item.fields.CD_basePlateTwisted?.value || false,
          basePlateFloorDamaged: item.fields.CD_basePlateFloorDamaged?.value || false,
          anchors: item.fields.CD_anchors?.value || false,
          anchorsDamaged: item.fields.CD_anchorsDamaged?.value || false,
          anchorsMissing: item.fields.CD_anchorsMissing?.value || false,
          anchorsTorqued: item.fields.CD_anchorsTorqued?.value || false,
          wireDeck: item.fields.CD_wireDeck?.value || false,
          wireDeckDamaged: item.fields.CD_wireDeckDamaged?.value || false,
          wireDeckMissing: item.fields.CD_wireDeckMissing?.value || false,
          wireDeckOutOfPosition: item.fields.CD_wireDeckOutOfPosition?.value || false,
          postProtector: item.fields.CD_postProtector?.value || false,
          postProtectorDamaged: item.fields.CD_postProtectorDamaged?.value || false,
          postProtectorMissing: item.fields.CD_postProtectorMissing?.value || false,
          postProtectorRepairRequired: item.fields.CD_postProtectorRepairRequired?.value || false,
          aisleGuarding: item.fields.CD_aisleGuarding?.value || false,
          aisleGuardingDamaged: item.fields.CD_aisleGuardingDamaged?.value || false,
          aisleGuardingMissing: item.fields.CD_aisleGuardingMissing?.value || false,
          aisleGuardingRepairRequired: item.fields.CD_aisleGuardingRepairRequired?.value || false
        };
      }))
    };

    res.json(transformedInspection);
  } catch (error) {
    next(error);
  }
});

export default router;
