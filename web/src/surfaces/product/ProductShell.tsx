import { NavLink, Outlet } from "react-router-dom";
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
    <div className="app-shell">
      <div className="topbar">
        <div>
          <div className="brand">DataR0w</div>
          <div className="muted">
            Surface Produit · prototype rejeu · <StatusBadge kind="sim" />
          </div>
        </div>
        <button type="button" className="ghost" onClick={() => setRole(null)}>
          Changer de rôle
        </button>
      </div>
      <div className="banner info">
        `avsim replay --realtime` n&apos;est pas encore codé. Ces vues sont
        constructibles contre le simulateur en mode rejeu — maquettes stables
        pour la navigation, sans faux flux « Mesuré ».
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
        En attente du mode rejeu temps réel
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

export function TeamView() {
  return (
    <ProductPage
      title="Team"
      body="Cockpit embarqué canal A — gros caractères, synchro équipage."
    />
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
