import { StatusBadge } from "../../components/StatusBadge";

function Placeholder({
  title,
  phase,
  detail,
}: {
  title: string;
  phase: string;
  detail: string;
}) {
  return (
    <div>
      <div className="topbar">
        <div>
          <h2>{title}</h2>
          <p className="muted">Maquette — pas de fausses données</p>
        </div>
        <StatusBadge kind="sim" />
      </div>
      <div className="panel" style={{ minHeight: 220 }}>
        <div className="banner info">
          <strong>À venir — {phase}</strong>
          <p style={{ margin: "0.4rem 0 0" }}>{detail}</p>
        </div>
        <div
          style={{
            marginTop: "1.2rem",
            height: 160,
            border: "1px dashed rgba(232,241,244,0.25)",
            borderRadius: 6,
            display: "grid",
            placeItems: "center",
            color: "#b7c9d1",
          }}
        >
          Graphique vide volontairement — pas de placeholder « réaliste »
        </div>
      </div>
    </div>
  );
}

export function SensorsView() {
  return (
    <Placeholder
      title="Capteurs"
      phase="Phase 4 (sensors/)"
      detail="Liste des 13 capteurs documentés côté hardware. Modèles de bruit non implémentés — aucune logique métier ici."
    />
  );
}

export function ObservabilityView() {
  return (
    <Placeholder
      title="Observabilité"
      phase="Phase 5 (analysis/)"
      detail="Livrable central (brief §14) : front de Pareto coût/erreur. Nécessite le mode Observabilité, pas encore implémenté."
    />
  );
}

export function SensitivityView() {
  return (
    <Placeholder
      title="Sensibilité"
      phase="Phase 5 (Sobol)"
      detail="Indices de Sobol — backend analysis/ absent."
    />
  );
}

export function DetectabilityView() {
  return (
    <Placeholder
      title="Détectabilité"
      phase="Phase 5"
      detail="Injection de défauts / taille d'effet — backend analysis/ absent."
    />
  );
}
