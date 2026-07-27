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

export type StrokeBarMetrics = {
  length_norm: number;
  catch_white: number;
  immersed: number;
  finish_white: number;
  catch_angle_deg?: number;
  L_slide_m?: number;
  immersion_threshold?: number;
};

export type DriveSeries = {
  u: number[];
  handle_force_N: number[];
  theta_deg?: number[];
  theta_dot_deg_s?: number[];
};

export type StrokeBarSeat = {
  seat: number;
  stroke_bar: StrokeBarMetrics;
  drive?: DriveSeries;
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
    stroke_bar?: StrokeBarMetrics;
    drive?: DriveSeries;
  }>;
  boat: {
    n_rowers: number;
    sculling: boolean;
    coxed: boolean;
    theta_catch_deg: number;
    theta_finish_deg: number;
    L_slide_m?: number;
    geometry_source: string;
  };
};

export type CrewSeatLive = {
  seat: number;
  F_peak_N: number;
  P_mean_W: number;
  phase_offset_ms: number;
  timing_ms: number;
  stroke_bar?: StrokeBarMetrics;
};

export type SyncAlert = {
  seat: number;
  timing_ms: number;
  note: string;
};

export type ReplayFrame =
  | {
      kind: "session";
      source: "simulated";
      boat_class: string;
      n_strokes: number;
      n_discard: number;
      n_keep: number;
      session_id?: string | null;
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
      arc_deg?: number;
      phase_lag_ms?: number;
      check_factor?: number;
      energy: Record<string, number>;
      crew?: CrewSeatLive[];
      sync_alert?: SyncAlert;
      series: { t_s: number[]; V_ms: number[] };
      stroke_bars?: StrokeBarSeat[];
    }
  | { kind: "end"; source: "simulated" };

export type CoachEvent = {
  event_id: string;
  t_utc: string;
  source: string;
  audio_ref: string | null;
  transcript: string | null;
  tag: string | null;
  session_id: string;
  nearest_stroke_index?: number | null;
};

export type SessionStrokeMark = {
  stroke_index: number;
  t_utc: string;
  cadence_spm: number;
  v_ms: number;
  check_factor: number;
  arc_deg?: number;
  phase_lag_ms?: number;
  energy?: Record<string, number>;
  stroke_bars?: StrokeBarSeat[];
};

export type SessionSummary = {
  session_id: string;
  boat_class: string;
  t_start_utc: string;
  source: string;
  n_strokes: number;
  n_events: number;
};

export type CompareResult = {
  session_id: string;
  event_id: string;
  nearest_stroke_index: number;
  metric: string;
  n: number;
  before: { stroke_indices: number[]; values: number[]; mean: number | null };
  after: { stroke_indices: number[]; values: number[]; mean: number | null };
  delta: number | null;
  significance: { calibrated: boolean; message: string };
  event: CoachEvent;
};

export type RameurStrokeCurve = {
  stroke_index: number;
  t_s: number[];
  handle_force_N: number[];
  F_peak_N: number;
  t_peak_s: number;
  phase_lag_ms_vs_stroke: number;
  P_mean_W: number;
  cadence_spm: number;
};

export type RameurReview = {
  source: "simulated";
  boat_class: string;
  seat: number;
  stroke_seat: number;
  reference_label: string;
  n_prev: number;
  strokes: RameurStrokeCurve[];
  last_phase_lag_ms: number | null;
  last_P_mean_W: number | null;
  power_calibration: { status: "indice"; message: string };
  boat: { n_rowers: number; sculling: boolean; coxed: boolean };
  validation: ClassInfo;
  session_id?: string | null;
  haptic_events: CoachEvent[];
};

export type ProgressionResult = {
  source: "simulated";
  boat_class: string;
  metric: string;
  metric_badge: "indice";
  points: Array<{
    session_id: string;
    t_start_utc: string;
    n_strokes: number;
    cadence_spm_mean: number;
    P_mean_W: number;
  }>;
  trend: {
    n_sessions: number;
    cadence_anchor_spm: number;
    cadence_tol_spm: number;
    P_first_W: number;
    P_last_W: number;
    delta_W: number;
    direction: "up" | "down" | "flat";
  } | null;
  note: string;
};

/** SSE `/api/replay/stream` — fetch+stream (EventSource ne peut pas poser le rôle). */
export async function openReplayStream(
  role: Role,
  opts: {
    boat_class?: string;
    n_strokes?: number;
    n_discard?: number;
    realtime?: boolean;
    session_id?: string;
    signal?: AbortSignal;
    onFrame: (frame: ReplayFrame) => void;
  },
): Promise<void> {
  const q = new URLSearchParams();
  q.set("boat_class", opts.boat_class ?? "2x");
  if (opts.n_strokes != null) q.set("n_strokes", String(opts.n_strokes));
  if (opts.n_discard != null) q.set("n_discard", String(opts.n_discard));
  if (opts.realtime != null) q.set("realtime", String(opts.realtime));
  if (opts.session_id) q.set("session_id", opts.session_id);

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

/** Mode C — pilote 2x uniquement (pas représentatif des autres classes). */
export type ObservabilitySubsetScore = {
  subset: string[];
  cost_eur: number;
  mass_g: number;
  rmse_V: number;
  rmse_com: number;
  rmse_combined: number;
  added?: string | null;
};

export type ObservabilityGain = {
  sensor_id: string;
  label: string;
  channel: string;
  cost_eur: number;
  mass_g: number;
  gain_rmse_combined: number;
  gain_rmse_V: number;
  gain_rmse_com: number;
  order: number;
};

export type ObservabilityResult = {
  pilot_label: string;
  boat_class: string;
  n_truths: number;
  greedy_path: ObservabilitySubsetScore[];
  sensor_gains: ObservabilityGain[];
  pareto_cost_error: ObservabilitySubsetScore[];
  elapsed_s?: number | null;
  source?: string;
  note?: string;
};

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
  poseSeries: (
    role: Role,
    boatClass: string,
    n = 41,
    opts?: { hull_builder?: string | null; hull_mould?: string | null },
  ) => {
    const q = new URLSearchParams({
      boat_class: boatClass,
      n: String(n),
      drive: "true",
    });
    if (opts?.hull_builder) q.set("hull_builder", opts.hull_builder);
    if (opts?.hull_mould) q.set("hull_mould", opts.hull_mould);
    return request<{
      source: string;
      boat_class: string;
      frames: import("./components/StrokeGeometry").PoseFrame[];
    }>(role, `/api/pose/series?${q}`);
  },
  createSession: (role: Role, boat_class = "2x") =>
    request<SessionSummary & { strokes: unknown[]; events: CoachEvent[] }>(
      role,
      "/api/sessions",
      { method: "POST", body: JSON.stringify({ boat_class }) },
    ),
  listSessions: (role: Role) =>
    request<{ sessions: SessionSummary[] }>(role, "/api/sessions"),
  getSession: (role: Role, sessionId: string) =>
    request<
      SessionSummary & {
        strokes: SessionStrokeMark[];
        events: CoachEvent[];
      }
    >(role, `/api/sessions/${encodeURIComponent(sessionId)}`),
  postEvent: (
    role: Role,
    sessionId: string,
    body: {
      source?: string;
      audio_ref?: string | null;
      transcript?: string | null;
      tag?: string | null;
      t_utc?: string | null;
    },
  ) =>
    request<CoachEvent>(
      role,
      `/api/sessions/${encodeURIComponent(sessionId)}/events`,
      { method: "POST", body: JSON.stringify(body) },
    ),
  compareEvent: (
    role: Role,
    sessionId: string,
    eventId: string,
    opts?: { n?: number; metric?: string },
  ) => {
    const q = new URLSearchParams({ event_id: eventId });
    if (opts?.n != null) q.set("n", String(opts.n));
    if (opts?.metric) q.set("metric", opts.metric);
    return request<CompareResult>(
      role,
      `/api/sessions/${encodeURIComponent(sessionId)}/compare?${q}`,
    );
  },
  rameurReview: (
    role: Role,
    opts: {
      boat_class?: string;
      seat?: number;
      n_prev?: number;
      session_id?: string | null;
    } = {},
  ) => {
    const q = new URLSearchParams({
      boat_class: opts.boat_class ?? "2x",
      seat: String(opts.seat ?? 1),
      n_prev: String(opts.n_prev ?? 10),
    });
    if (opts.session_id) q.set("session_id", opts.session_id);
    return request<RameurReview>(role, `/api/rameur/review?${q}`);
  },
  rameurProgression: (role: Role, boat_class = "2x", cadence_tol_spm = 2) => {
    const q = new URLSearchParams({
      boat_class,
      cadence_tol_spm: String(cadence_tol_spm),
    });
    return request<ProgressionResult>(role, `/api/rameur/progression?${q}`);
  },
  /** Mode C précalculé — pilote 2x uniquement. */
  observability: (role: Role) =>
    request<ObservabilityResult>(role, "/api/analysis/observability"),
};
