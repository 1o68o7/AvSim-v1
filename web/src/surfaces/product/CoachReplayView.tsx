import { useEffect, useMemo, useState } from "react";
import {
  ApiError,
  api,
  type CompareResult,
  type CoachEvent,
  type SessionSummary,
} from "../../api";
import {
  StrokeGeometry,
  type PoseFrame,
} from "../../components/StrokeGeometry";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

function frameAtU(frames: PoseFrame[], u: number): PoseFrame | null {
  if (!frames.length) return null;
  let best = frames[0];
  let bestD = Math.abs(frames[0].u - u);
  for (const f of frames) {
    const d = Math.abs(f.u - u);
    if (d < bestD) {
      best = f;
      bestD = d;
    }
  }
  return best;
}

export function CoachReplayView() {
  const { role } = useApp();
  const [sessions, setSessions] = useState<SessionSummary[]>([]);
  const [sessionId, setSessionId] = useState<string>("");
  const [events, setEvents] = useState<CoachEvent[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [compare, setCompare] = useState<CompareResult | null>(null);
  const [metric, setMetric] = useState<"v_ms" | "cadence_spm" | "check_factor">(
    "v_ms",
  );
  const [nWin, setNWin] = useState(3);
  const [uCursor, setUCursor] = useState(0.4);
  const [frames, setFrames] = useState<PoseFrame[]>([]);
  const [poseLoading, setPoseLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const pose = useMemo(() => frameAtU(frames, uCursor), [frames, uCursor]);

  async function refreshSessions() {
    if (!role) return;
    try {
      const r = await api.listSessions(role);
      setSessions(r.sessions);
      if (!sessionId && r.sessions.length) {
        setSessionId(r.sessions[0].session_id);
      }
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    }
  }

  useEffect(() => {
    void refreshSessions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [role]);

  useEffect(() => {
    if (!role || !sessionId) {
      setEvents([]);
      return;
    }
    api
      .getSession(role, sessionId)
      .then((s) => setEvents(s.events))
      .catch((e: ApiError) => setError(e.message));
  }, [role, sessionId]);

  useEffect(() => {
    if (!role) return;
    setPoseLoading(true);
    api
      .poseSeries(role, "2x", 41)
      .then((r) => setFrames(r.frames))
      .catch((e: ApiError) => setError(e.message))
      .finally(() => setPoseLoading(false));
  }, [role]);

  async function onSelectEvent(eventId: string) {
    if (!role || !sessionId) return;
    setSelected(eventId);
    try {
      const c = await api.compareEvent(role, sessionId, eventId, {
        n: nWin,
        metric,
      });
      setCompare(c);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
      setCompare(null);
    }
  }

  useEffect(() => {
    if (selected) void onSelectEvent(selected);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [metric, nWin]);

  return (
    <div className="coach-replay">
      <div className="team-cockpit-head">
        <div>
          <h2>Coach Replay</h2>
          <p className="muted">
            StrokeGeometry + timeline events · classe 2x
          </p>
        </div>
        <StatusBadge kind="sim" />
      </div>

      <div className="banner beta">
        Signification non calibrée — Mode D non disponible. Les écarts
        avant/après sont bruts, sans seuil de détectabilité.
      </div>

      {error && <div className="banner network">{error}</div>}

      <div className="team-controls" style={{ marginBottom: "0.75rem" }}>
        <label>
          Séance{" "}
          <select
            value={sessionId}
            onChange={(e) => {
              setSessionId(e.target.value);
              setSelected(null);
              setCompare(null);
            }}
          >
            <option value="">—</option>
            {sessions.map((s) => (
              <option key={s.session_id} value={s.session_id}>
                {s.boat_class} · {s.t_start_utc} · {s.n_events} evt /{" "}
                {s.n_strokes} coups
              </option>
            ))}
          </select>
        </label>
        <button type="button" className="ghost" onClick={() => void refreshSessions()}>
          Rafraîchir
        </button>
        <span className="muted">
          Annoter d&apos;abord via Coach live (même session).
        </span>
      </div>

      <div className="coach-replay-grid">
        <div>
          <StrokeGeometry frame={pose} loading={poseLoading} />
          <label className="muted" style={{ display: "block", marginTop: "0.5rem" }}>
            u = {uCursor.toFixed(2)}
            <input
              type="range"
              min={0}
              max={1}
              step={0.01}
              value={uCursor}
              onChange={(e) => setUCursor(Number(e.target.value))}
              style={{ width: "100%" }}
            />
          </label>
        </div>

        <div className="panel">
          <h3>Timeline events</h3>
          {events.length === 0 && (
            <p className="muted">Aucun événement — lancez Coach live 2x.</p>
          )}
          <ul className="event-timeline">
            {events.map((ev) => (
              <li key={ev.event_id}>
                <button
                  type="button"
                  className={
                    selected === ev.event_id ? "event-chip active" : "event-chip"
                  }
                  onClick={() => void onSelectEvent(ev.event_id)}
                >
                  <span className="event-chip-t">{ev.t_utc}</span>
                  <span>
                    {ev.tag ?? "—"} · {ev.source}
                  </span>
                  {ev.transcript && (
                    <span className="muted">{ev.transcript}</span>
                  )}
                </button>
              </li>
            ))}
          </ul>

          <div className="field-grid" style={{ maxHeight: "none", marginTop: "0.75rem" }}>
            <label className="field-row">
              <span>Métrique</span>
              <select
                value={metric}
                onChange={(e) =>
                  setMetric(e.target.value as typeof metric)
                }
              >
                <option value="v_ms">vitesse</option>
                <option value="cadence_spm">cadence</option>
                <option value="check_factor">check_factor</option>
              </select>
              <span />
            </label>
            <label className="field-row">
              <span>Fenêtre N</span>
              <input
                type="number"
                min={1}
                max={20}
                value={nWin}
                onChange={(e) => setNWin(Number(e.target.value))}
              />
              <span />
            </label>
          </div>
        </div>
      </div>

      {compare && (
        <div className="panel" style={{ marginTop: "1rem" }}>
          <h3>Avant / après (coup {compare.nearest_stroke_index})</h3>
          <div className="banner beta">{compare.significance.message}</div>
          <div className="metric-row">
            <div className="metric">
              <div className="label">Avant (N={compare.before.stroke_indices.length})</div>
              <div className="value">
                {compare.before.mean != null
                  ? compare.before.mean.toFixed(3)
                  : "—"}
              </div>
            </div>
            <div className="metric">
              <div className="label">Après (N={compare.after.stroke_indices.length})</div>
              <div className="value">
                {compare.after.mean != null
                  ? compare.after.mean.toFixed(3)
                  : "—"}
              </div>
            </div>
            <div className="metric">
              <div className="label">Δ brut ({compare.metric})</div>
              <div className="value">
                {compare.delta != null
                  ? (compare.delta >= 0 ? "+" : "") + compare.delta.toFixed(3)
                  : "—"}
              </div>
              <div className="target">pas de seuil Mode D</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
