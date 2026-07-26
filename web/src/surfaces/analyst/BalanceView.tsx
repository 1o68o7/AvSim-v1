import Plot from "react-plotly.js";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { useEnsureSimulate } from "../../hooks/useEnsureSimulate";

function tone(
  value: number,
  band: [number, number] | null | undefined,
): "ok" | "warn" | "bad" {
  if (!band) return "warn";
  const [lo, hi] = band;
  if (value >= lo && value <= hi) return "ok";
  const mid = 0.5 * (lo + hi);
  const span = Math.max(hi - lo, 1e-9);
  return Math.abs(value - mid) < 1.5 * span ? "warn" : "bad";
}

function Metric({
  label,
  value,
  target,
  unit,
  band,
}: {
  label: string;
  value: number;
  target: string;
  unit: string;
  band?: [number, number] | null;
}) {
  const t = tone(value, band);
  return (
    <div className={`metric ${t}`}>
      <div className="label">{label}</div>
      <div className="value">
        {Number.isFinite(value) ? value.toFixed(2) : "—"}
        <span style={{ fontSize: "0.8rem" }}> {unit}</span>
      </div>
      <div className="target">cible §9.2 : {target}</div>
    </div>
  );
}

export function BalanceView() {
  const { result, busy, networkError, retry, selected, boatClass } =
    useEnsureSimulate();

  const status = result?.validation ?? selected;
  const isBeta = status?.status === "beta";

  return (
    <div>
      <div className="topbar">
        <div>
          <h2>Bilan</h2>
          <p className="muted">
            Plausibilité §9.2 — <StatusBadge kind="sim" /> · /api/simulate
          </p>
        </div>
        {status && (
          <StatusBadge
            kind={classBadgeKind(status.status)}
            label={status.label}
          />
        )}
      </div>

      {isBeta && (
        <div className="banner beta">
          Classe <strong>{boatClass}</strong> — Bêta non calibrée (bandeau
          permanent)
        </div>
      )}
      {networkError && (
        <div className="banner network">
          {networkError}{" "}
          <button type="button" className="ghost" onClick={() => void retry()}>
            Réessayer
          </button>
        </div>
      )}
      {busy && !result && (
        <div className="banner info">
          Chargement /api/simulate…
          <div className="skeleton" style={{ height: 14, marginTop: 8 }} />
        </div>
      )}

      {!result && !busy && !networkError && (
        <div className="panel">
          <p className="muted">Aucune simulation — lancez depuis Bateau ou réessayez.</p>
          <button type="button" onClick={() => void retry()}>
            Lancer /api/simulate
          </button>
        </div>
      )}

      {result && (() => {
        const e = result.energy;
        const t = result.targets_9_2;
        const etaOut =
          e.eta_blade < t.eta_blade[0] || e.eta_blade > t.eta_blade[1];
        return (
          <>
            <div className="metric-row">
              <Metric
                label="v_mean"
                value={e.v_mean_ms}
                unit="m/s"
                target={
                  t.v_mean_band
                    ? `${t.v_mean_band[0].toFixed(2)}–${t.v_mean_band[1].toFixed(2)}`
                    : "±8% v_ref"
                }
                band={t.v_mean_band}
              />
              <Metric label="v_min" value={e.v_min_ms} unit="m/s" target="—" />
              <Metric label="v_max" value={e.v_max_ms} unit="m/s" target="—" />
              <Metric
                label="check_factor"
                value={e.check_factor}
                unit="m/s"
                target={`${t.check_factor[0]}–${t.check_factor[1]}`}
                band={t.check_factor}
              />
              <Metric
                label="T_drive"
                value={e.T_drive_s}
                unit="s"
                target="sortie modèle"
              />
              <Metric
                label="η_blade"
                value={e.eta_blade}
                unit=""
                target={`${t.eta_blade[0]}–${t.eta_blade[1]}`}
                band={t.eta_blade}
              />
            </div>

            {etaOut && (
              <div className="banner info" style={{ marginTop: "0.8rem" }}>
                {result.eta_note} Voir <code>STATE.md</code> /{" "}
                <code>ROADMAP-PRODUCTION.md</code>.
              </div>
            )}

            <div className="panel" style={{ marginTop: "1rem" }}>
              <h3>Décomposition énergétique (J) — champs API</h3>
              <Plot
                data={[
                  {
                    type: "bar",
                    orientation: "h",
                    y: ["Bilan"],
                    x: [e.E_prop_J],
                    name: "E_prop",
                    marker: { color: "#2f7d4a" },
                  },
                  {
                    type: "bar",
                    orientation: "h",
                    y: ["Bilan"],
                    x: [e.E_blade_loss_J],
                    name: "E_blade_loss",
                    marker: { color: "#c45c26" },
                  },
                  {
                    type: "bar",
                    orientation: "h",
                    y: ["Bilan"],
                    x: [e.E_oar_ke_jump_J],
                    name: "E_oar_ke_jump",
                    marker: { color: "#b8860b" },
                  },
                  {
                    type: "bar",
                    orientation: "h",
                    y: ["Bilan"],
                    x: [e.E_hull_drag_J],
                    name: "E_hull",
                    marker: { color: "#3a9bb0" },
                  },
                  {
                    type: "bar",
                    orientation: "h",
                    y: ["Bilan"],
                    x: [e.E_aero_J],
                    name: "E_aero",
                    marker: { color: "#b7c9d1" },
                  },
                ]}
                layout={{
                  barmode: "stack",
                  paper_bgcolor: "rgba(0,0,0,0)",
                  plot_bgcolor: "rgba(0,0,0,0)",
                  font: { color: "#e8f1f4" },
                  height: 180,
                  margin: { t: 20, r: 20, b: 40, l: 60 },
                  legend: { orientation: "h" },
                  xaxis: { title: "Joules" },
                }}
                config={{ displayModeBar: false, responsive: true }}
                style={{ width: "100%" }}
              />
            </div>
          </>
        );
      })()}
    </div>
  );
}
