import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import cloudkit from '../services/cloudkit.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * GET /api/customers
 * Fetch all customers for the authenticated user
 */
router.get('/', async (req, res, next) => {
  try {
    const rawUserId = req.user?.userId;
    const userId = rawUserId != null ? String(rawUserId).trim() : null;
    if (!userId) {
      return res.status(401).json({ error: 'User ID missing' });
    }
    console.log('📋 GET /customers - userId:', userId);

    if (!process.env.CLOUDKIT_CONTAINER_ID || !process.env.CLOUDKIT_API_TOKEN) {
      console.error('CloudKit not configured!');
      return res.json([]);
    }

    const customers = await cloudkit.fetchCustomers(userId);
    console.log('📦 CloudKit response type:', typeof customers);
    console.log('📦 Is array?', Array.isArray(customers));
    if (customers) console.log('📦 First 200 chars:', JSON.stringify(customers).substring(0, 200));

    // Ensure we got an array
    if (!Array.isArray(customers)) {
      console.error('❌ CloudKit returned non-array!');
      return res.json([]);
    }
    
    console.log('✅ Got', customers.length, 'records from CloudKit');

    // Transform CloudKit response to simpler format
    // Core Data + CloudKit prefixes fields with 'CD_'
    const transformedCustomers = customers.map(record => ({
      id: record.recordName,
      name: record.fields.CD_name?.value || '',
      contactName: record.fields.CD_contactName?.value || '',
      phone: record.fields.CD_phone?.value || '',
      address: record.fields.CD_address?.value || '',
      city: record.fields.CD_city?.value || '',
      state: record.fields.CD_state?.value || '',
      zipCode: record.fields.CD_zipCode?.value || '',
      site: record.fields.CD_site?.value || '',
      createdDate: record.fields.CD_createdDate?.value || record.created?.timestamp
    }));

    console.log('📤 Sending', transformedCustomers.length, 'customers to frontend');
    res.json(transformedCustomers);
  } catch (error) {
    console.error('❌ ERROR in GET /customers:', error.message);
    // Return empty array on error to prevent frontend crash
    res.json([]);
  }
});

/**
 * GET /api/customers/:id
 * Fetch a single customer by ID
 */
router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const customer = await cloudkit.fetchRecord(id, 'Customer');

    if (!customer) {
      return res.status(404).json({ error: 'Customer not found' });
    }

    // Verify ownership (Core Data + CloudKit uses CD_ prefix)
    // Normalize both values to strings for comparison to avoid type coercion issues
    const customerUserId = customer.fields.CD_userId?.value != null ? String(customer.fields.CD_userId.value) : null;
    const requestUserId = req.user.userId != null ? String(req.user.userId) : null;

    if (!customerUserId || !requestUserId || customerUserId !== requestUserId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const transformedCustomer = {
      id: customer.recordName,
      name: customer.fields.CD_name?.value || '',
      contactName: customer.fields.CD_contactName?.value || '',
      phone: customer.fields.CD_phone?.value || '',
      address: customer.fields.CD_address?.value || '',
      city: customer.fields.CD_city?.value || '',
      state: customer.fields.CD_state?.value || '',
      zipCode: customer.fields.CD_zipCode?.value || '',
      site: customer.fields.CD_site?.value || '',
      createdDate: customer.fields.CD_createdDate?.value || customer.created?.timestamp
    };

    res.json(transformedCustomer);
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/customers/:id/inspections
 * Fetch all inspections for a customer
 */
router.get('/:id/inspections', async (req, res, next) => {
  try {
    const { id } = req.params;
    
    // Validate CloudKit configuration
    if (!process.env.CLOUDKIT_CONTAINER_ID || !process.env.CLOUDKIT_API_TOKEN) {
      console.error('CloudKit not configured!');
      return res.json([]);
    }
    
    // Verify customer ownership first (Core Data + CloudKit uses CD_ prefix)
    const customer = await cloudkit.fetchRecord(id, 'CD_Customer');

    // Normalize both values to strings for comparison
    const customerUserId = customer?.fields.CD_userId?.value != null ? String(customer.fields.CD_userId.value) : null;
    const requestUserId = req.user.userId != null ? String(req.user.userId) : null;

    if (!customer || !customerUserId || !requestUserId || customerUserId !== requestUserId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const inspections = await cloudkit.fetchInspections(id);

    // Ensure we got an array
    if (!Array.isArray(inspections)) {
      console.error('CloudKit returned non-array for inspections:', inspections);
      return res.json([]);
    }

    const transformedInspections = inspections.map(record => ({
      id: record.recordName,
      date: record.fields.CD_date?.value,
      inspectorName: record.fields.CD_inspectorName?.value || '',
      customerId: id,
      createdDate: record.created?.timestamp
    }));

    res.json(transformedInspections);
  } catch (error) {
    console.error('Error fetching inspections:', error);
    // Return empty array on error
    res.json([]);
  }
});

export default router;
