# Systems Inspector — Web

React (Vite) + TypeScript frontend using **CloudKit JS** (Sign in with Apple) to read the same data as the iOS app. PDF generation is client-side (e.g. jsPDF).

## Deploy

**Domain (example):** sysinspect.skynet97.org — adjust for your environment.  
Build with the repo **Dockerfile**; see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Stack

- React 18, TypeScript, Vite, Tailwind  
- React Router, TanStack Query, Zustand (auth UI state)  
- CloudKit JS + API token from Apple Developer / CloudKit Dashboard  

## Layout

```
webapp/
├── frontend/          # App source
├── docs/              # DEPLOYMENT, CLOUDKIT_SETUP, SECURITY
├── Dockerfile
└── inject-cloudkit-config.cjs
```

## Local dev

```bash
cd frontend
npm install
cp .env.example .env   # VITE_CLOUDKIT_* — see .env.example
npm run dev
```

Default dev server: http://localhost:5173

## Env (frontend)

Match the iOS container where applicable, e.g. `iCloud.SysInspectDB`. See `frontend/.env.example`.

## Documentation

- [DEPLOYMENT.md](docs/DEPLOYMENT.md)  
- [CLOUDKIT_SETUP.md](docs/CLOUDKIT_SETUP.md)  
- [SECURITY.md](docs/SECURITY.md)  
