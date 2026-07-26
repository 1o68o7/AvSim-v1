import { NavLink, Outlet } from "react-router-dom";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

const links = [
  { to: "/analyst/bateau", label: "Bateau", soon: false },
  { to: "/analyst/coup", label: "Coup", soon: false },
  { to: "/analyst/bilan", label: "Bilan", soon: false },
  { to: "/analyst/equipage", label: "Équipage", soon: false },
  { to: "/analyst/capteurs", label: "Capteurs", soon: true },
  { to: "/analyst/observabilite", label: "Observabilité", soon: true },
  { to: "/analyst/sensibilite", label: "Sensibilité", soon: true },
  { to: "/analyst/detectabilite", label: "Détectabilité", soon: true },
];

export function AnalystShell() {
  const { setRole, boatClass } = useApp();
  return (
    <div className="app-shell">
      <div className="topbar">
        <div>
          <div className="brand">DataR0w</div>
          <div className="muted">
            Surface Analyste · classe {boatClass} · <StatusBadge kind="sim" />
          </div>
        </div>
        <button type="button" className="ghost" onClick={() => setRole(null)}>
          Changer de rôle
        </button>
      </div>
      <nav className="nav">
        {links.map((l) => (
          <NavLink
            key={l.to}
            to={l.to}
            className={({ isActive }) =>
              `${isActive ? "active" : ""} ${l.soon ? "soon" : ""}`
            }
          >
            {l.label}
            {l.soon ? " · 🟡" : ""}
          </NavLink>
        ))}
      </nav>
      <div style={{ marginTop: "1rem" }}>
        <Outlet />
      </div>
    </div>
  );
}
