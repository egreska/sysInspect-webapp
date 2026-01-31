# API Documentation - Systems Inspector Web

Complete REST API reference for the Systems Inspector web application.

## 🌐 Base URL

**Production:** `https://sysinspect.skynet97.org/api`  
**Development:** `http://localhost:3001/api`

---

## 🔐 Authentication

All endpoints except `/auth/login` require JWT authentication.

### Headers

```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

### JWT Token Expiration

Tokens expire after **7 days**.

---

## 📋 Endpoints

### Health Check

#### GET `/health`

Check API health status (no authentication required).

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-01-30T12:00:00.000Z"
}
```

---

## 🔑 Authentication

### Login

#### POST `/auth/login`

Authenticate user and receive JWT token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "your-password"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com"
  }
}
```

**Errors:**
- `400` - Missing email or password
- `401` - Invalid credentials
- `403` - Account inactive

### Verify Token

#### POST `/auth/verify`

Verify JWT token validity.

**Headers:**
```http
Authorization: Bearer <token>
```

**Response:**
```json
{
  "valid": true,
  "user": {
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com"
  }
}
```

---

## 👥 Customers

### Get All Customers

#### GET `/customers`

Fetch all customers for authenticated user.

**Response:**
```json
[
  {
    "id": "customer-id-1",
    "name": "ACME Corporation",
    "contactName": "John Doe",
    "phone": "555-0100",
    "address": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "zipCode": "10001",
    "site": "Building A",
    "createdDate": "2026-01-15T10:00:00.000Z"
  }
]
```

### Get Customer by ID

#### GET `/customers/:id`

Fetch single customer details.

**Parameters:**
- `id` (path) - Customer ID

**Response:**
```json
{
  "id": "customer-id-1",
  "name": "ACME Corporation",
  "contactName": "John Doe",
  "phone": "555-0100",
  "address": "123 Main Street",
  "city": "New York",
  "state": "NY",
  "zipCode": "10001",
  "site": "Building A",
  "createdDate": "2026-01-15T10:00:00.000Z"
}
```

**Errors:**
- `404` - Customer not found
- `403` - Access denied (not your customer)

### Get Customer Inspections

#### GET `/customers/:id/inspections`

Fetch all inspections for a customer.

**Parameters:**
- `id` (path) - Customer ID

**Response:**
```json
[
  {
    "id": "inspection-id-1",
    "date": "2026-01-30T14:00:00.000Z",
    "inspectorName": "Jane Inspector",
    "customerId": "customer-id-1",
    "createdDate": "2026-01-30T14:00:00.000Z"
  }
]
```

---

## 🔍 Inspections

### Get Inspection by ID

#### GET `/inspections/:id`

Fetch complete inspection with all items, customer info, and photos.

**Parameters:**
- `id` (path) - Inspection ID

**Response:**
```json
{
  "id": "inspection-id-1",
  "date": "2026-01-30T14:00:00.000Z",
  "inspectorName": "Jane Inspector",
  "customer": {
    "id": "customer-id-1",
    "name": "ACME Corporation",
    "contactName": "John Doe",
    "phone": "555-0100",
    "address": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "zipCode": "10001",
    "site": "Building A"
  },
  "items": [
    {
      "id": "item-id-1",
      "location": "Warehouse A, Row 5",
      "bayNumber": "10",
      "importance": "Critical",
      "comments": "Immediate attention required",
      "sequenceNumber": 1,
      "photoData": "base64-encoded-image-data",
      
      "upright": true,
      "uprightFrontDamage": true,
      "uprightFrontTwisted": false,
      "uprightRearDamage": false,
      "uprightRearTwisted": false,
      "uprightAlignmentOutOfAlignment": true,
      "uprightAlignmentOutOfVerticalPlumb": false,
      
      "beam": false,
      "beamFrontDamage": false,
      "beamFrontBowed": false,
      "beamRearDamage": false,
      "beamRearBowed": false,
      
      "bracingDiagonal": false,
      "bracingHorizontal": false,
      "bracingDamage": false,
      
      "basePlate": true,
      "basePlateDamaged": true,
      "basePlateTwisted": false,
      "basePlateFloorDamaged": false,
      
      "anchors": true,
      "anchorsDamaged": false,
      "anchorsMissing": false,
      "anchorsTorqued": true,
      
      "wireDeck": false,
      "wireDeckDamaged": false,
      "wireDeckMissing": false,
      "wireDeckOutOfPosition": false,
      
      "postProtector": true,
      "postProtectorDamaged": false,
      "postProtectorMissing": false,
      "postProtectorRepairRequired": false,
      
      "aisleGuarding": false,
      "aisleGuardingDamaged": false,
      "aisleGuardingMissing": false,
      "aisleGuardingRepairRequired": false
    }
  ]
}
```

**Errors:**
- `404` - Inspection not found
- `403` - Access denied

---

## 📄 Reports

### Generate PDF Report

#### GET `/reports/inspection/:id`

Generate and download PDF report for an inspection.

**Parameters:**
- `id` (path) - Inspection ID

**Response:**
- Content-Type: `application/pdf`
- Content-Disposition: `attachment; filename=inspection-report-{id}.pdf`
- Binary PDF data

**Errors:**
- `404` - Inspection not found
- `403` - Access denied

**Example Usage:**
```javascript
// JavaScript/Fetch
const response = await fetch(`/api/reports/inspection/${inspectionId}`, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});

const blob = await response.blob();
const url = window.URL.createObjectURL(blob);
const link = document.createElement('a');
link.href = url;
link.download = 'inspection-report.pdf';
link.click();
```

```bash
# cURL
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://sysinspect.skynet97.org/api/reports/inspection/INSPECTION_ID \
  --output report.pdf
```

---

## 🔒 Security

### Rate Limiting

**Limit:** 100 requests per 15 minutes per IP address

**Response when exceeded:**
```json
{
  "error": "Too many requests, please try again later"
}
```

### CORS

**Allowed Origins:**
- `https://sysinspect.skynet97.org` (production)
- `http://localhost:5173` (development)

**Allowed Methods:**
- `GET`, `POST`

### Error Responses

All errors follow this format:

```json
{
  "error": "Error message here"
}
```

**Common Status Codes:**
- `400` - Bad Request (invalid input)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (access denied)
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error
- `502` - Bad Gateway (CloudKit error)

---

## 📊 Data Models

### User

```typescript
interface User {
  userId: string;
  email: string;
}
```

### Customer

```typescript
interface Customer {
  id: string;
  name: string;
  contactName?: string;
  phone?: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  site?: string;
  createdDate?: string;
}
```

### Inspection

```typescript
interface Inspection {
  id: string;
  date?: string;
  inspectorName?: string;
  customerId?: string;
  customer?: Customer;
  items?: InspectionItem[];
  createdDate?: string;
}
```

### InspectionItem

```typescript
interface InspectionItem {
  id: string;
  location: string;
  bayNumber?: string;
  importance: 'Critical' | 'Repair' | 'Monitor';
  comments?: string;
  sequenceNumber: number;
  photoData?: string | null;
  
  // Damage flags (all boolean)
  upright: boolean;
  uprightFrontDamage?: boolean;
  // ... (30+ damage-related boolean fields)
}
```

---

## 🧪 Testing

### Using cURL

```bash
# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Get customers (save token from login)
curl http://localhost:3001/api/customers \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get inspection
curl http://localhost:3001/api/inspections/INSPECTION_ID \
  -H "Authorization: Bearer YOUR_TOKEN"

# Download PDF
curl http://localhost:3001/api/reports/inspection/INSPECTION_ID \
  -H "Authorization: Bearer YOUR_TOKEN" \
  --output report.pdf
```

### Using Postman

1. Import collection (see `postman_collection.json`)
2. Set environment variable `base_url` to `http://localhost:3001/api`
3. Login to get token
4. Token is automatically saved to environment
5. Test other endpoints

---

## 📈 Performance

### Response Times (Target)

- Health check: < 10ms
- Authentication: < 200ms
- List customers: < 500ms
- Get inspection: < 1000ms (including photos)
- Generate PDF: < 3000ms

### Optimization

- CloudKit responses are cached for 5 minutes
- Photos are lazy-loaded
- Pagination available for large datasets
- Compression enabled

---

## 🔄 Versioning

**Current Version:** v1.0

**API Stability:** Stable

**Breaking Changes:** Will be announced with major version bump

---

## 📞 Support

### Documentation
- [Deployment Guide](./DEPLOYMENT.md)
- [CloudKit Setup](./CLOUDKIT_SETUP.md)
- [Main README](../README.md)

### Issues
- Check error responses for details
- Review application logs
- Contact administrator

---

**API Documentation Version:** 1.0  
**Last Updated:** January 30, 2026  
**Base URL:** `https://sysinspect.skynet97.org/api`

---

**Happy coding!** 🚀
