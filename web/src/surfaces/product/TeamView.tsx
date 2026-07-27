import { useEffect, useRef, useState } from "react";
import Plot from "react-plotly.js";
import { ApiError, openReplayStream, type ReplayFrame } from "../../api";
import { StatusBadge } from "../../components/StatusBadge";
import { StrokeLengthBarStack, type StrokeBarMetrics } from "../../components/StrokeLengthBar";
import { useApp } from "../../state";

type LiveState = {
  cadence: number | null;
  power: number | null;
  stroke: number | null;
  boatClass: string;
  force: number[];
  handleSpeed: number[];
  x: number[];
  bars: Array<{ seat: number; bar: StrokeBarMetrics }>;
};

const EMPTY: LiveState = {
  cadence: null,
  power: null,
  stroke: null,
  boatClass: "2x",
  force: [],
  handleSpeed: [],
  x: [],
  bars: [],
};

/** Team — 4 quadrants Peach/FM (brief visuels §5). */
export function TeamView() {
  const { role } = useApp();
  const [live, setLive] = useState<LiveState>(EMPTY);
  const [status, setStatus] = useState<"idle" | "running" | "ended" | "error">(
    "idle",
  );
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    return () => {
      abortRef.current?.abort();
    };
  }, []);

  async function start() {
    if (!role) return;
    abortRef.current?.abort();
    const ac = new AbortController();
    abortRef.current = ac;
    setLive({ ...EMPTY, boatClass: "2x" });
    setError(null);
    setStatus("running");
    try {
      await openReplayStream(role, {
        boat_class: "2x",
        n_strokes: 12,
        n_discard: 4,
        realtime: true,
        signal: ac.signal,
        onFrame: (frame: ReplayFrame) => {
          if (frame.kind === "session") {
            setLive((prev) => ({ ...prev, boatClass: frame.boat_class }));
          } else if (frame.kind === "stroke") {
            const F = frame.series.handle_force_N ?? [];
            const w = frame.series.theta_dot_deg_s ?? [];
            const n = Math.max(F.length, w.length);
            const x = Array.from({ length: n }, (_, i) =>
              n > 1 ? i / (n - 1) : 0,
            );
            const bars = (frame.crew ?? [])
              .filter((c) => c.stroke_bar)
              .map((c) => ({ seat: c.seat, bar: c.stroke_bar! }));
            setLive({
              boatClass: frame.boat_class,
              cadence: frame.cadence_spm,
              power:
                frame.P_rower_mean_W ??
                frame.energy?.P_rower_mean_W ??
                null,
              stroke: frame.stroke_index,
              force: F,
              handleSpeed: w.map((v) => Math.abs(v)),
              x,
              bars,
            });
          } else if (frame.kind === "end") {
            setStatus("ended");
          }
        },
      });
      if (!ac.signal.aborted) setStatus((s) => (s === "running" ? "ended" : s));
    } catch (e) {
      if ((e as Error).name === "AbortError") return;
      setStatus("error");
      setError(e instanceof ApiError ? e.message : String(e));
    }
  }

  function stop() {
    abortRef.current?.abort();
    abortRef.current = null;
    setStatus("idle");
  }

  const fmt = (n: number | null, digits: number) =>
    n == null ? "—" : n.toFixed(digits);

  const plotLayout = {
    paper_bgcolor: "rgba(0,0,0,0)",
    plot_bgcolor: "rgba(6,16,24,0.25)",
    font: { color: "#e8f1f4", family: "Source Sans 3", size: 10 },
    margin: { t: 8, r: 8, b: 28, l: 36 },
    height: 160,
    showlegend: false,
    xaxis: { visible: false },
    yaxis: { gridcolor: "rgba(255,255,255,0.08)", zeroline: false },
  };

  return (
    <div className="team-cockpit">
      <div className="team-cockpit-head">
        <div>
          <h2>Team</h2>
          <p className="muted">
            Canal A · 4 quadrants · classe {live.boatClass}
          </p>
        </div>
        <StatusBadge kind="sim" />
      </div>

      <div className="team-quad" aria-live="polite">
        <div className="team-quad-cell">
          <h3>Force</h3>
          {live.force.length ? (
            <Plot
              data={[
                {
                  x: live.x,
                  y: live.force,
                  type: "scatter",
                  mode: "lines",
                  line: { color: "#3a9bb0", width: 2.5 },
                },
              ]}
              layout={plotLayout as never}
              config={{ displayModeBar: false, responsive: true, staticPlot: true }}
              style={{ width: "100%" }}
            />
          ) : (
            <p className="muted">En attente du flux…</p>
          )}
        </div>

        <div className="team-quad-cell">
          <h3>Longueur de coup</h3>
          {live.bars.length ? (
            <StrokeLengthBarStack bars={live.bars} />
          ) : (
            <p className="muted">—</p>
          )}
        </div>

        <div className="team-quad-cell">
          <h3>Vitesse poignée</h3>
          {live.handleSpeed.length ? (
            <Plot
              data={[
                {
                  x: live.x,
                  y: live.handleSpeed,
                  type: "scatter",
                  mode: "lines",
                  line: { color: "#d4c4a8", width: 2.5 },
                },
              ]}
              layout={plotLayout as never}
              config={{ displayModeBar: false, responsive: true, staticPlot: true }}
              style={{ width: "100%" }}
            />
          ) : (
            <p className="muted">—</p>
          )}
        </div>

        <div className="team-quad-cell">
          <h3>Chiffres</h3>
          <div className="team-quad-digits">
            <div>
              <div className="team-metric-label">Puissance</div>
              <div className="team-metric-value">{fmt(live.power, 0)}</div>
              <div className="team-metric-unit">W · indice</div>
            </div>
            <div>
              <div className="team-metric-label">Cadence</div>
              <div className="team-metric-value">{fmt(live.cadence, 0)}</div>
              <div className="team-metric-unit">c/min</div>
            </div>
          </div>
        </div>
      </div>

      <div className="team-controls">
        {status === "running" ? (
          <button type="button" onClick={stop}>
            Arrêter
          </button>
        ) : (
          <button type="button" onClick={() => void start()}>
            Démarrer rejeu 2x
          </button>
        )}
        <span className="muted">
          {status === "running" && live.stroke != null
            ? `Coup ${live.stroke} · ${fmt(live.power, 0)} W`
            : status === "ended"
              ? "Fin de séance"
              : status === "error"
                ? "Erreur"
                : "Idle"}
        </span>
      </div>
      {error && <div className="banner network">{error}</div>}
    </div>
  );
}
