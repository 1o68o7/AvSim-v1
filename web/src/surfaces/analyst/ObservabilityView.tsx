import { useEffect, useMemo, useState } from "react";
import Plot from "react-plotly.js";
import { ApiError, api, type ObservabilityResult } from "../../api";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

/**
 * Mode C — Observabilité. Résultat réel pilote 2x (pas une maquette).
 * Bandeau permanent : non représentatif des 7 autres classes.
 */
export function ObservabilityView() {
  const { role } = useApp();
  const [data, setData] = useState<ObservabilityResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!role) return;
    setLoading(true);
    api
      .observability(role)
      .then(setData)
      .catch((e: unknown) =>
        setError(e instanceof ApiError ? e.message : String(e)),
      )
      .finally(() => setLoading(false));
  }, [role]);

  const pareto = data?.pareto_cost_error ?? [];
  const gains = data?.sensor_gains ?? [];

  const paretoPlot = useMemo(() => {
    if (!pareto.length) return [];
    return [
      {
        x: pareto.map((p) => p.cost_eur),
        y: pareto.map((p) => p.rmse_combined),
        text: pareto.map((p) =>
          p.subset.length ? p.subset.join("+") : "(aucun)",
        ),
        type: "scatter" as const,
        mode: "lines+markers" as const,
        name: "Pareto coût / erreur",
        line: { color: "#3a9bb0", width: 2 },
        marker: { size: 9, color: "#d4c4a8" },
        hovertemplate:
          "%{text}<br>%{x:.0f} € · err=%{y:.3f}<extra></extra>",
      },
    ];
  }, [pareto]);

  return (
    <div>
      <div className="topbar">
        <div>
          <h2>Observabilité</h2>
          <p className="muted">
            Mode C — valeur du capteur · <StatusBadge kind="sim" />
          </p>
        </div>
        <StatusBadge kind="beta" label="Pilote 2x" />
      </div>

      <div className="banner beta">
        <strong>Pilote classe 2x uniquement</strong> — les 7 autres classes
        restent bloquées, cf. STATE.md. Non représentatif des autres classes
        tant que Phase 1 n&apos;avance pas plus loin.
      </div>

      {error && <div className="banner network">{error}</div>}
      {loading && <p className="muted">Chargement du résultat Mode C…</p>}

      {data && (
        <>
          <p className="muted" style={{ marginTop: "0.75rem" }}>
            {data.n_truths} vérités terrain 2x · sélection avant gloutonne ·{" "}
            {data.elapsed_s != null
              ? `calcul ${data.elapsed_s.toFixed(0)} s`
              : "résultat précalculé"}
          </p>

          <div className="grid-2" style={{ marginTop: "1rem" }}>
            <div className="panel">
              <h3>Front de Pareto coût / erreur</h3>
              <p className="muted">
                Erreur combinée = RMSE(V) + 10·RMSE(CdM). Chemin glouton.
              </p>
              {paretoPlot.length ? (
                <Plot
                  data={paretoPlot as never}
                  layout={{
                    paper_bgcolor: "rgba(0,0,0,0)",
                    plot_bgcolor: "rgba(6,16,24,0.35)",
                    font: { color: "#e8f1f4", family: "Source Sans 3" },
                    margin: { t: 20, r: 20, b: 48, l: 56 },
                    height: 300,
                    xaxis: {
                      title: "Coût (€)",
                      gridcolor: "rgba(255,255,255,0.08)",
                    },
                    yaxis: {
                      title: "Erreur combinée",
                      gridcolor: "rgba(255,255,255,0.08)",
                    },
                    showlegend: false,
                  }}
                  config={{ displayModeBar: false, responsive: true }}
                  style={{ width: "100%" }}
                />
              ) : (
                <p className="muted">Pas de points Pareto.</p>
              )}
            </div>

            <div className="panel">
              <h3>Capteur → gain par métrique</h3>
              <p className="muted">
                Gain = réduction d&apos;erreur à l&apos;ajout glouton.
              </p>
              <table className="data">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Capteur</th>
                    <th>€</th>
                    <th>Δ err V</th>
                    <th>Δ err CdM</th>
                    <th>Δ err Σ</th>
                  </tr>
                </thead>
                <tbody>
                  {gains.map((g) => (
                    <tr key={g.sensor_id}>
                      <td>{g.order}</td>
                      <td>{g.label}</td>
                      <td>{g.cost_eur.toFixed(0)}</td>
                      <td>{g.gain_rmse_V.toFixed(3)}</td>
                      <td>{g.gain_rmse_com.toFixed(3)}</td>
                      <td>{g.gain_rmse_combined.toFixed(3)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="panel" style={{ marginTop: "1rem" }}>
            <h3>Chemin glouton</h3>
            <ul className="event-timeline">
              {data.greedy_path.map((p, i) => (
                <li key={i}>
                  <span className="event-chip">
                    <span className="event-chip-t">
                      {p.cost_eur.toFixed(0)} € · {p.mass_g.toFixed(0)} g
                    </span>
                    <span>
                      {p.subset.length
                        ? p.subset.join(" + ")
                        : "(aucun capteur)"}
                    </span>
                    <span className="muted">
                      err Σ={p.rmse_combined.toFixed(3)} · V=
                      {p.rmse_V.toFixed(3)} · CdM={p.rmse_com.toFixed(3)}
                    </span>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </>
      )}
    </div>
  );
}
