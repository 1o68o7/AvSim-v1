import { useEffect, useRef, useState } from "react";
import { ApiError, openReplayStream, type ReplayFrame } from "../../api";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

type Live = {
  cadence: number | null;
  speed: number | null;
  distance: number | null;
  stroke: number | null;
  boatClass: string;
};

const EMPTY: Live = {
  cadence: null,
  speed: null,
  distance: null,
  stroke: null,
  boatClass: "2x",
};

/** Vue Team — cockpit embarqué, 3 chiffres gros, alimentée par le SSE replay. */
export function TeamView() {
  const { role } = useApp();
  const [live, setLive] = useState<Live>(EMPTY);
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
            setLive({
              boatClass: frame.boat_class,
              cadence: frame.cadence_spm,
              speed: frame.v_ms,
              distance: frame.distance_m,
              stroke: frame.stroke_index,
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

  return (
    <div className="team-cockpit">
      <div className="team-cockpit-head">
        <div>
          <h2>Team</h2>
          <p className="muted">
            Canal A · lecture en mouvement · classe {live.boatClass}
          </p>
        </div>
        <StatusBadge kind="sim" />
      </div>

      <div className="team-metrics" aria-live="polite">
        <div className="team-metric">
          <div className="team-metric-label">Cadence</div>
          <div className="team-metric-value">{fmt(live.cadence, 0)}</div>
          <div className="team-metric-unit">c/min</div>
        </div>
        <div className="team-metric">
          <div className="team-metric-label">Vitesse</div>
          <div className="team-metric-value">{fmt(live.speed, 2)}</div>
          <div className="team-metric-unit">m/s</div>
        </div>
        <div className="team-metric">
          <div className="team-metric-label">Distance</div>
          <div className="team-metric-value">{fmt(live.distance, 0)}</div>
          <div className="team-metric-unit">m</div>
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
          {status === "idle" && "Prêt — flux simulé"}
          {status === "running" &&
            `Coup ${live.stroke == null ? "…" : live.stroke + 1}`}
          {status === "ended" && "Séance terminée"}
          {status === "error" && (error ?? "Erreur")}
        </span>
      </div>
    </div>
  );
}
