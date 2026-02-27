# Systems Inspector Web Application

Professional web application for accessing CloudKit data and generating inspection reports.

## 🌐 Deployment Information

**Domain:** sysinspect.skynet97.org  
**Platform:** Coolify  
**Status:** Development

## 🏗️ Architecture

### Frontend (CloudKit JS)
- **Framework:** React 18 + TypeScript
- **Build Tool:** Vite
- **UI Library:** Shadcn/UI (Radix UI + Tailwind CSS)
- **State Management:** React Query (TanStack Query)
- **Routing:** React Router v6
- **CloudKit:** CloudKit JS browser SDK (Sign in with Apple)
- **PDF Generation:** jsPDF (client-side)
- **Rich Text Editor:** TipTap (ProseMirror-based)

### Deployment
- **Container:** Docker (frontend-only)
- **Reverse Proxy:** Handled by Coolify
- **SSL:** Automatic via Coolify/Let's Encrypt

## 📁 Project Structure

```
webapp/
├── frontend/                 # React + TypeScript frontend
│   ├── src/
│   │   ├── components/      # Reusable UI components
│   │   ├── pages/           # Route pages
│   │   ├── services/       # CloudKit, API, PDF
│   │   ├── store/          # Auth state
│   │   └── types/          # TypeScript types
│   └── package.json
│
├── _unused/                  # Deprecated (backend, old docker config)
│   ├── backend/             # Former Node.js backend
│   ├── docker-entrypoint.sh
│   ├── docker-compose.local.yml
│   └── README.md
│
├── docs/                     # Documentation
│   ├── DEPLOYMENT.md        # Coolify deployment guide
│   ├── CLOUDKIT_SETUP.md    # CloudKit configuration
│   └── API.md               # API documentation
│
├── Dockerfile                # Frontend-only production build
└── README.md
```

## 🚀 Quick Start

### Prerequisites
- Node.js 20+
- npm or yarn
- CloudKit API token

### Local Development

```bash
cd webapp/frontend
npm install
cp .env.example .env   # Add VITE_CLOUDKIT_* variables
npm run dev
```

Frontend runs at http://localhost:5173

### Environment Variables

See `frontend/.env.example`:
- `VITE_CLOUDKIT_CONTAINER_ID` – CloudKit container (must match iOS: `iCloud.SysInspectDB`)
- `VITE_CLOUDKIT_API_TOKEN` – API token from CloudKit Dashboard → API Access → API Tokens
- `VITE_CLOUDKIT_ENVIRONMENT` – `development` or `production`

## 🔐 CloudKit Configuration

The webapp uses **CloudKit JS** (browser SDK) with Sign in with Apple. Create an API token in CloudKit Dashboard → API Access → API Tokens.

See `docs/CLOUDKIT_SETUP.md` for detailed instructions.

## 📦 Deployment to Coolify

```bash
docker build -t sysinspect-webapp .
# Deploy via Coolify - see docs/DEPLOYMENT.md
```

## 🎯 Features

- ✅ Sign in with Apple (CloudKit JS)
- ✅ Customer list and search
- ✅ Inspection browsing
- ✅ Report viewing
- ✅ PDF export (client-side)
- ✅ Responsive design

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [CloudKit Setup](docs/CLOUDKIT_SETUP.md)
- [API Documentation](docs/API.md)

## 🔒 Security

- HTTPS only
- Sign in with Apple (CloudKit)
- CORS, input validation, XSS protection

---

**Built with ❤️ for Professional Inspectors**
