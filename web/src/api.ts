export type Role = "analyst" | "product";

/**
 * Base URL de l'API.
 * - Prod / Render : `VITE_API_URL` (ex. https://avsim-api.onrender.com)
 * - Dev local : non défini → même origine + proxy Vite `/api` → localhost:8000
 */
function apiBase(): string {
  const raw = (import.meta.env.VITE_API_URL as string | undefined)?.trim();
  if (!raw) return "";
  const withScheme =
    raw.startsWith("http://") || raw.startsWith("https://")
      ? raw
      : `https://${raw}`;
  return withScheme.replace(/\/$/, "");
}

const API_BASE = apiBase();

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  role: Role,
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set("X-DataR0w-Role", role);
  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  } catch {
    throw new ApiError(0, "Réseau indisponible — API non joignable");
  }
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const j = await res.json();
      detail = j.detail ?? JSON.stringify(j);
    } catch {
      /* ignore */
    }
    throw new ApiError(res.status, String(detail));
  }
  return res.json() as Promise<T>;
}

export type ClassInfo = {
  code: string;
  status: "validated" | "beta" | "unknown";
  label: string;
  detail: string;
  n_rowers: number;
  sculling: boolean;
  coxed: boolean;
  v_ref_ms: number | null;
};

export type SimulateResult = {
  source: "simulated";
  stroke_index: number;
  validation: ClassInfo;
  energy: Record<string, number>;
  targets_9_2: {
    v_ref_ms: number | null;
    v_mean_band: [number, number] | null;
    eta_blade: [number, number];
    check_factor: [number, number];
    P_rower_W: [number, number];
  };
  eta_note: string;
  series: {
    t_s: number[];
    u: number[];
    theta_deg: number[];
    handle_force_N: number[];
    V_ms: number[];
    immersion: number[];
  };
  crew: Array<{
    seat: number;
    phase_offset_ms: number;
    E_handle_J: number;
    P_mean_W: number;
  }>;
  boat: {
    n_rowers: number;
    sculling: boolean;
    coxed: boolean;
    theta_catch_deg: number;
    theta_finish_deg: number;
    geometry_source: string;
  };
};

export type ReplayFrame =
  | {
      kind: "session";
      source: "simulated";
      boat_class: string;
      n_strokes: number;
      n_discard: number;
      n_keep: number;
      validation: ClassInfo;
    }
  | {
      kind: "stroke";
      source: "simulated";
      boat_class: string;
      stroke_index: number;
      T_s: number;
      cadence_spm: number;
      v_ms: number;
      distance_m: number;
      energy: Record<string, number>;
      series: { t_s: number[]; V_ms: number[] };
    }
  | { kind: "end"; source: "simulated" };

/** SSE `/api/replay/stream` — fetch+stream (EventSource ne peut pas poser le rôle). */
export async function openReplayStream(
  role: Role,
  opts: {
    boat_class?: string;
    n_strokes?: number;
    n_discard?: number;
    realtime?: boolean;
    signal?: AbortSignal;
    onFrame: (frame: ReplayFrame) => void;
  },
): Promise<void> {
  const q = new URLSearchParams();
  q.set("boat_class", opts.boat_class ?? "2x");
  if (opts.n_strokes != null) q.set("n_strokes", String(opts.n_strokes));
  if (opts.n_discard != null) q.set("n_discard", String(opts.n_discard));
  if (opts.realtime != null) q.set("realtime", String(opts.realtime));

  let res: Response;
  try {
    res = await fetch(`${API_BASE}/api/replay/stream?${q}`, {
      headers: { "X-DataR0w-Role": role },
      signal: opts.signal,
    });
  } catch (e) {
    if ((e as Error).name === "AbortError") return;
    throw new ApiError(0, "Réseau indisponible — API non joignable");
  }
  if (!res.ok) {
    throw new ApiError(res.status, res.statusText || "replay stream failed");
  }
  if (!res.body) {
    throw new ApiError(0, "Pas de corps de flux SSE");
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buf = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    let sep: number;
    while ((sep = buf.indexOf("\n\n")) >= 0) {
      const block = buf.slice(0, sep);
      buf = buf.slice(sep + 2);
      for (const line of block.split("\n")) {
        if (line.startsWith("data: ")) {
          opts.onFrame(JSON.parse(line.slice(6)) as ReplayFrame);
        }
      }
    }
  }
}

export const api = {
  classes: (role: Role) =>
    request<{ classes: ClassInfo[] }>(role, "/api/classes"),
  hulls: (role: Role, boatClass?: string) =>
    request<{ moulds: Array<Record<string, unknown>> }>(
      role,
      `/api/hull_moulds${boatClass ? `?boat_class=${encodeURIComponent(boatClass)}` : ""}`,
    ),
  params: (role: Role, code: string, builder?: string | null, mould?: string | null) => {
    const q = new URLSearchParams();
    if (builder) q.set("hull_builder", builder);
    if (mould) q.set("hull_mould", mould);
    const qs = q.toString();
    return request<Record<string, unknown>>(
      role,
      `/api/params/${encodeURIComponent(code)}${qs ? `?${qs}` : ""}`,
    );
  },
  simulate: (
    role: Role,
    body: {
      boat_class: string;
      hull_builder?: string | null;
      hull_mould?: string | null;
      overrides?: Record<string, unknown>;
      n_strokes?: number;
      n_discard?: number;
    },
  ) =>
    request<SimulateResult>(role, "/api/simulate", {
      method: "POST",
      body: JSON.stringify(body),
    }),
};
