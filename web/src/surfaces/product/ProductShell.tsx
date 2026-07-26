import { NavLink, Outlet } from "react-router-dom";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

export { TeamView } from "./TeamView";
export { CoachLiveView } from "./CoachLiveView";
export { CoachReplayView } from "./CoachReplayView";

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

export function RowerView() {
  return (
    <div className="panel">
      <h2>Rameur</h2>
      <p className="muted">
        Calibration haptique coup+1 + écran minimal (cadence, distance, timing).
        Prototypage via rejeu simulé.
      </p>
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
