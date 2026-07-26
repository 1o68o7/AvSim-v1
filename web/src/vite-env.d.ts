/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** URL publique de l'API (Render). Vide en local → proxy Vite. */
  readonly VITE_API_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

declare module "react-plotly.js";
