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
    const { userId } = req.user;
    const customers = await cloudkit.fetchCustomers(userId);

    // Transform CloudKit response to simpler format
    const transformedCustomers = customers.map(record => ({
      id: record.recordName,
      name: record.fields.name?.value || '',
      contactName: record.fields.contactName?.value || '',
      phone: record.fields.phone?.value || '',
      address: record.fields.address?.value || '',
      city: record.fields.city?.value || '',
      state: record.fields.state?.value || '',
      zipCode: record.fields.zipCode?.value || '',
      site: record.fields.site?.value || '',
      createdDate: record.fields.createdDate?.value || record.created?.timestamp
    }));

    res.json(transformedCustomers);
  } catch (error) {
    next(error);
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

    // Verify ownership
    if (customer.fields.userId?.value !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const transformedCustomer = {
      id: customer.recordName,
      name: customer.fields.name?.value || '',
      contactName: customer.fields.contactName?.value || '',
      phone: customer.fields.phone?.value || '',
      address: customer.fields.address?.value || '',
      city: customer.fields.city?.value || '',
      state: customer.fields.state?.value || '',
      zipCode: customer.fields.zipCode?.value || '',
      site: customer.fields.site?.value || '',
      createdDate: customer.fields.createdDate?.value || customer.created?.timestamp
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
    
    // Verify customer ownership first
    const customer = await cloudkit.fetchRecord(id, 'Customer');
    if (!customer || customer.fields.userId?.value !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const inspections = await cloudkit.fetchInspections(id);

    const transformedInspections = inspections.map(record => ({
      id: record.recordName,
      date: record.fields.date?.value,
      inspectorName: record.fields.inspectorName?.value || '',
      customerId: id,
      createdDate: record.created?.timestamp
    }));

    res.json(transformedInspections);
  } catch (error) {
    next(error);
  }
});

export default router;
