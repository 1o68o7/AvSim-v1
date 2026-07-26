import { useEffect, useRef, useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import { ApiError, openReplayStream, type ReplayFrame } from "../../api";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

const links = [
  { to: "/product/rameur", label: "Rameur" },
  { to: "/product/team", label: "Team" },
  { to: "/product/coach-live", label: "Coach live" },
  { to: "/product/coach-replay", label: "Coach Replay" },
];

export function ProductShell() {
  const { setRole } = useApp();
  return (
    <div className="app-shell product-shell">
      <div className="topbar">
        <div>
          <div className="brand">DataR0w</div>
          <div className="muted">
            Surface Produit · rejeu · <StatusBadge kind="sim" />
          </div>
        </div>
        <button type="button" className="ghost" onClick={() => setRole(null)}>
          Changer de rôle
        </button>
      </div>
      <div className="banner info">
        Flux <code>GET /api/replay/stream</code> — même grain que{" "}
        <code>avsim replay --realtime</code>. Toujours <StatusBadge kind="sim" />
        , jamais « Mesuré ».
      </div>
      <nav className="nav">
        {links.map((l) => (
          <NavLink
            key={l.to}
            to={l.to}
            className={({ isActive }) => (isActive ? "active" : "")}
          >
            {l.label}
          </NavLink>
        ))}
      </nav>
      <div style={{ marginTop: "1rem" }}>
        <Outlet />
      </div>
    </div>
  );
}

function ProductPage({
  title,
  body,
}: {
  title: string;
  body: string;
}) {
  return (
    <div className="panel">
      <h2>{title}</h2>
      <p className="muted">{body}</p>
      <div
        style={{
          marginTop: "1rem",
          padding: "2rem",
          textAlign: "center",
          border: "1px dashed rgba(232,241,244,0.25)",
          borderRadius: 6,
        }}
      >
        En attente du branchement rejeu
      </div>
    </div>
  );
}

export function RowerView() {
  return (
    <ProductPage
      title="Rameur"
      body="Calibration haptique coup+1 + écran minimal (cadence, distance, timing). Prototypage via rejeu simulé."
    />
  );
}

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

export function CoachLiveView() {
  return (
    <ProductPage
      title="Coach live"
      body="Canal B — multi-métriques + annotation vocale timecodée."
    />
  );
}

export function CoachReplayView() {
  return (
    <ProductPage
      title="Coach Replay"
      body="Réutilise le composant Vue Coup Analyste + annotations — branché quand le rejeu existe."
    />
  );
}
