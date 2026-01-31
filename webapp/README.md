# Systems Inspector Web Application

Professional web application for accessing CloudKit data and generating inspection reports.

## 🌐 Deployment Information

**Domain:** sysinspect.skynet97.org  
**Platform:** Coolify  
**Status:** Development

## 🏗️ Architecture

### Frontend
- **Framework:** React 18 + TypeScript
- **Build Tool:** Vite
- **UI Library:** Shadcn/UI (Radix UI + Tailwind CSS)
- **State Management:** React Query (TanStack Query)
- **Routing:** React Router v6
- **PDF Generation:** jsPDF + html2canvas
- **Rich Text Editor:** TipTap (ProseMirror-based)

### Backend
- **Runtime:** Node.js 20+
- **Framework:** Express.js
- **Authentication:** JWT + CloudKit Web Services
- **CloudKit SDK:** Custom implementation using CloudKit Web Services API
- **PDF Generation:** PDFKit (server-side)
- **Validation:** Zod
- **Security:** Helmet, CORS, rate-limiting

### Deployment
- **Container:** Docker multi-stage build
- **Reverse Proxy:** Handled by Coolify
- **SSL:** Automatic via Coolify/Let's Encrypt
- **Environment:** Production-ready configuration

## 📁 Project Structure

```
webapp/
├── frontend/                 # React + TypeScript frontend
│   ├── src/
│   │   ├── components/      # Reusable UI components
│   │   ├── pages/          # Route pages
│   │   ├── services/       # API clients
│   │   ├── hooks/          # Custom React hooks
│   │   ├── types/          # TypeScript types
│   │   └── utils/          # Utility functions
│   ├── public/             # Static assets
│   └── package.json
│
├── backend/                 # Node.js + Express backend
│   ├── src/
│   │   ├── routes/         # API routes
│   │   ├── controllers/    # Request handlers
│   │   ├── services/       # Business logic
│   │   ├── models/         # Data models
│   │   └── middleware/     # Express middleware
│   └── package.json
│
├── docs/                    # Documentation
│   ├── DEPLOYMENT.md       # Coolify deployment guide
│   ├── CLOUDKIT_SETUP.md  # CloudKit configuration
│   └── API.md             # API documentation
│
├── docker-compose.yml      # Local development
├── Dockerfile             # Production container
└── README.md             # This file
```

## 🚀 Quick Start

### Prerequisites
- Node.js 20+
- npm or yarn
- Docker (for deployment)
- CloudKit credentials

### Local Development

```bash
# Install dependencies
cd webapp/frontend && npm install
cd ../backend && npm install

# Start backend (port 3001)
cd backend
npm run dev

# Start frontend (port 5173)
cd frontend
npm run dev
```

### Environment Variables

See `.env.example` files in frontend/ and backend/ directories.

## 🔐 CloudKit Configuration

The webapp uses CloudKit Web Services API to access data from the iOS app.

**Required:**
1. CloudKit Container ID
2. API Token from Apple Developer
3. Server-to-Server Key

See `docs/CLOUDKIT_SETUP.md` for detailed instructions.

## 📦 Deployment to Coolify

```bash
# Build production image
docker build -t sysinspect-webapp .

# Deploy via Coolify
# See docs/DEPLOYMENT.md for detailed steps
```

## 🎯 Features

### Current Features
- ✅ CloudKit authentication
- ✅ Customer list and search
- ✅ Inspection browsing
- ✅ Report viewing
- ✅ PDF export (matching iOS format)
- ✅ Responsive design
- ✅ Secure authentication

### Planned Features
- [ ] Report editing
- [ ] Photo management
- [ ] Multi-user collaboration
- [ ] Real-time sync
- [ ] Advanced filtering
- [ ] Batch operations

## 🛠️ Tech Stack Details

### All Open Source!

**Frontend:**
- React (MIT License)
- TypeScript (Apache 2.0)
- Vite (MIT License)
- Tailwind CSS (MIT License)
- React Query (MIT License)
- TipTap (MIT License)

**Backend:**
- Node.js (MIT License)
- Express (MIT License)
- Zod (MIT License)
- PDFKit (MIT License)

**Infrastructure:**
- Docker (Apache 2.0)
- Coolify (Apache 2.0)

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [CloudKit Setup](docs/CLOUDKIT_SETUP.md)
- [API Documentation](docs/API.md)

## 🔒 Security

- HTTPS only (enforced by Coolify)
- JWT authentication
- CloudKit server-to-server authentication
- Rate limiting
- CORS configuration
- Input validation
- SQL injection prevention
- XSS protection

## 📄 License

MIT License - See LICENSE file

---

**Built with ❤️ for Professional Inspectors**
