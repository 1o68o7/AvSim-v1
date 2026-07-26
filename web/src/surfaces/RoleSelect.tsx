import { StatusBadge } from "../components/StatusBadge";
import { useApp } from "../state";
import type { Role } from "../api";

export function RoleSelect() {
  const { setRole } = useApp();
  const pick = (r: Role) => setRole(r);

  return (
    <div className="app-shell role-hero">
      <div>
        <div className="brand">DataR0w</div>
        <h1>Choisir une surface</h1>
        <p className="muted">
          Deux interfaces, un seul moteur. Aucune sortie du simulateur n&apos;est
          une mesure — badge <StatusBadge kind="sim" /> permanent côté simu.
        </p>
      </div>
      <div className="role-choices">
        <button className="role-choice" type="button" onClick={() => pick("analyst")}>
          <h2>Analyste</h2>
          <p className="muted">
            Décider quels capteurs acheter. Simulation, bilan §9.2, (plus tard)
            observabilité.
          </p>
        </button>
        <button className="role-choice" type="button" onClick={() => pick("product")}>
          <h2>Produit</h2>
          <p className="muted">
            Rameur / Team / Coach — prototypage contre rejeu simulé (matériel
            Phase 8).
          </p>
        </button>
      </div>
    </div>
  );
}
