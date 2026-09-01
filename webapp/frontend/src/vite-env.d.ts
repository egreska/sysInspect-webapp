/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_CLOUDKIT_CONTAINER_ID: string;
  readonly VITE_CLOUDKIT_API_TOKEN: string;
  readonly VITE_CLOUDKIT_ENVIRONMENT: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
