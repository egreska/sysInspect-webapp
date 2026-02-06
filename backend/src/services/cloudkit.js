import crypto from 'crypto';
import axios from 'axios';

/**
 * CloudKit Web Services Client
 * 
 * Implements CloudKit Web Services API for accessing data from iOS app
 * Documentation: https://developer.apple.com/documentation/cloudkitjs
 */
class CloudKitService {
  constructor() {
    this.containerIdentifier = process.env.CLOUDKIT_CONTAINER_ID;
    this.environment = process.env.CLOUDKIT_ENVIRONMENT || 'development';
    this.apiToken = process.env.CLOUDKIT_API_TOKEN;
    this.serverToServerKeyID = process.env.CLOUDKIT_SERVER_KEY_ID;
    this.privateKey = process.env.CLOUDKIT_PRIVATE_KEY;
    this.baseURL = `https://api.apple-cloudkit.com/database/1/${this.containerIdentifier}/${this.environment}/private`;
    
    // Log configuration status (not the actual values!)
    const configured = !!(
      this.containerIdentifier &&
      this.apiToken &&
      this.serverToServerKeyID &&
      this.privateKey
    );
    
    if (configured) {
      console.log('✅ CloudKit service initialized');
      console.log(`   Container: ${this.containerIdentifier}`);
      console.log(`   Environment: ${this.environment}`);
    } else {
      console.warn('⚠️  CloudKit NOT configured - missing environment variables!');
      if (!this.containerIdentifier) console.warn('   Missing: CLOUDKIT_CONTAINER_ID');
      if (!this.apiToken) console.warn('   Missing: CLOUDKIT_API_TOKEN');
      if (!this.serverToServerKeyID) console.warn('   Missing: CLOUDKIT_SERVER_KEY_ID');
      if (!this.privateKey) console.warn('   Missing: CLOUDKIT_PRIVATE_KEY');
    }
  }

  /**
   * Generate authentication signature for CloudKit requests
   */
  generateSignature(date, requestBody, path) {
    const message = `${date}:${requestBody}:${path}`;
    const signature = crypto
      .createSign('sha256')
      .update(message)
      .sign(this.privateKey, 'base64');
    return signature;
  }

  /**
   * Make authenticated request to CloudKit
   */
  async makeRequest(endpoint, method = 'POST', data = {}) {
    // Check if CloudKit is configured
    if (!this.containerIdentifier || !this.apiToken || !this.serverToServerKeyID || !this.privateKey) {
      throw new Error('CloudKit not configured - missing environment variables');
    }

    const date = new Date().toISOString();
    const path = `/database/1/${this.containerIdentifier}/${this.environment}/private/${endpoint}`;
    const requestBody = JSON.stringify(data);
    
    const headers = {
      'Content-Type': 'application/json',
      'X-Apple-CloudKit-Request-KeyID': this.serverToServerKeyID,
      'X-Apple-CloudKit-Request-ISO8601Date': date,
      'X-Apple-CloudKit-Request-SignatureV1': this.generateSignature(date, requestBody, path)
    };

    try {
      console.log(`🌐 CloudKit request: ${method} ${endpoint}`);
      const response = await axios({
        method,
        url: `${this.baseURL}/${endpoint}`,
        data,
        headers
      });
      console.log(`✅ CloudKit response: ${response.data?.records?.length || 0} records`);
      return response.data;
    } catch (error) {
      console.error('❌ CloudKit API Error:', {
        endpoint,
        status: error.response?.status,
        reason: error.response?.data?.reason,
        message: error.message
      });
      throw new Error(`CloudKit API Error: ${error.response?.data?.reason || error.message}`);
    }
  }

  /**
   * Query records from CloudKit
   * Core Data + CloudKit stores data in 'com.apple.coredata.cloudkit.zone'
   */
  async queryRecords(recordType, filters = [], sortBy = null, resultsLimit = 100) {
    const query = {
      query: {
        recordType,
        filterBy: filters.length > 0 ? filters : undefined,
        sortBy: sortBy ? [sortBy] : undefined
      },
      zoneID: {
        zoneName: 'com.apple.coredata.cloudkit.zone'
      },
      resultsLimit
    };

    const response = await this.makeRequest('records/query', 'POST', query);
    return response.records || [];
  }

  /**
   * Fetch a single record by ID
   * Core Data + CloudKit stores data in 'com.apple.coredata.cloudkit.zone'
   */
  async fetchRecord(recordName, recordType) {
    const data = {
      records: [{
        recordName,
        recordType
      }],
      zoneID: {
        zoneName: 'com.apple.coredata.cloudkit.zone'
      }
    };

    const response = await this.makeRequest('records/lookup', 'POST', data);
    return response.records?.[0];
  }

  /**
   * Fetch customers for a user
   * Core Data entities are prefixed with 'CD_'
   */
  async fetchCustomers(userId) {
    const filters = [{
      fieldName: 'CD_userId',
      comparator: 'EQUALS',
      fieldValue: {
        value: userId,
        type: 'STRING'
      }
    }];

    const sortBy = {
      fieldName: 'CD_name',
      ascending: true
    };

    return await this.queryRecords('CD_Customer', filters, sortBy);
  }

  /**
   * Fetch inspections for a customer
   * Core Data entities are prefixed with 'CD_'
   */
  async fetchInspections(customerId) {
    const filters = [{
      fieldName: 'CD_customer',
      comparator: 'EQUALS',
      fieldValue: {
        value: {
          recordName: customerId
        },
        type: 'REFERENCE'
      }
    }];

    const sortBy = {
      fieldName: 'CD_date',
      ascending: false
    };

    return await this.queryRecords('CD_Inspection', filters, sortBy);
  }

  /**
   * Fetch inspection items for an inspection
   * Core Data entities are prefixed with 'CD_'
   */
  async fetchInspectionItems(inspectionId) {
    const filters = [{
      fieldName: 'CD_inspection',
      comparator: 'EQUALS',
      fieldValue: {
        value: {
          recordName: inspectionId
        },
        type: 'REFERENCE'
      }
    }];

    const sortBy = {
      fieldName: 'CD_sequenceNumber',
      ascending: true
    };

    return await this.queryRecords('CD_InspectionItem', filters, sortBy);
  }

  /**
   * Fetch user by email
   * Core Data entities are prefixed with 'CD_'
   */
  async fetchUserByEmail(email) {
    const filters = [{
      fieldName: 'CD_email',
      comparator: 'EQUALS',
      fieldValue: {
        value: email,
        type: 'STRING'
      }
    }];

    const users = await this.queryRecords('CD_User', filters, null, 1);
    return users[0] || null;
  }

  /**
   * Download asset (photo) from CloudKit
   */
  async downloadAsset(downloadURL) {
    try {
      const response = await axios.get(downloadURL, {
        responseType: 'arraybuffer'
      });
      return Buffer.from(response.data).toString('base64');
    } catch (error) {
      console.error('Asset download error:', error.message);
      return null;
    }
  }
}

export default new CloudKitService();
