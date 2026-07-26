import { useMemo, useState } from "react";
import Plot from "react-plotly.js";
import { BoatSchematic } from "../../components/BoatSchematic";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { useApp } from "../../state";

export function StrokeView() {
  const { result } = useApp();
  const [uCursor, setUCursor] = useState(0.4);
  const [showRefs, setShowRefs] = useState(false);

  const idx = useMemo(() => {
    if (!result) return 0;
    const u = result.series.u;
    let best = 0;
    let bestD = Infinity;
    for (let i = 0; i < u.length; i++) {
      const d = Math.abs(u[i] - uCursor);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }, [result, uCursor]);

  if (!result) {
    return (
      <div className="panel">
        <h2>Coup</h2>
        <p className="muted">
          Aucune simulation — lancez-en une depuis <strong>Bateau</strong>.
        </p>
      </div>
    );
  }

  const { series, boat, validation, crew } = result;
  const thetaNow = series.theta_deg[idx] ?? 0;
  const A = series.A_ms2 ?? [];
  const fish = crew[0]?.fish;
  const cursorShape = {
    type: "line" as const,
    x0: uCursor,
    x1: uCursor,
    y0: 0,
    y1: 1,
    yref: "paper" as const,
    line: { color: "rgba(232,241,244,0.55)", width: 1 },
  };
  const shapes = showRefs
    ? [
        {
          type: "line" as const,
          x0: 0.17,
          x1: 0.17,
          y0: 0,
          y1: 1,
          yref: "paper" as const,
          line: { dash: "dot", color: "rgba(212,196,168,0.7)" },
        },
        {
          type: "line" as const,
          x0: 0.4,
          x1: 0.4,
          y0: 0,
          y1: 1,
          yref: "paper" as const,
          line: { dash: "dot", color: "rgba(58,155,176,0.8)" },
        },
        cursorShape,
      ]
    : [cursorShape];

  // θ au curseur pour marqueur poisson
  const fishTheta = series.theta_deg[idx];
  const fishOmega = series.theta_dot_deg_s?.[idx];

  return (
    <div>
      <div className="topbar">
        <div>
          <h2>Coup</h2>
          <p className="muted">
            Force, θ, V, a — curseur u unique — <StatusBadge kind="sim" />
          </p>
        </div>
        <StatusBadge kind={classBadgeKind(validation.status)} label={validation.label} />
      </div>
      {validation.status === "beta" && (
        <div className="banner beta">
          Classe {validation.code} — Bêta non calibrée
        </div>
      )}

      <div className="panel" style={{ marginBottom: "0.8rem" }}>
        <label>
          <input
            type="checkbox"
            checked={showRefs}
            onChange={(e) => setShowRefs(e.target.checked)}
          />{" "}
          Repères sourcés (Catch Slip / F_u_peak…) — overlay optionnel, pas des
          mesures de ce coup
        </label>
        <div style={{ marginTop: 8 }}>
          <label className="muted">
            Curseur u = {uCursor.toFixed(2)} (θ = {thetaNow.toFixed(1)}°)
          </label>
          <input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={uCursor}
            onChange={(e) => setUCursor(Number(e.target.value))}
            style={{ width: "100%" }}
          />
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <Plot
            data={[
              {
                x: series.u,
                y: series.handle_force_N,
                name: "F poignée",
                type: "scatter",
                mode: "lines",
                line: { color: "#3a9bb0", width: 2 },
                xaxis: "x",
                yaxis: "y",
              },
              {
                x: series.u,
                y: series.theta_deg,
                name: "θ aviron",
                type: "scatter",
                mode: "lines",
                line: { color: "#d4c4a8", width: 2 },
                xaxis: "x",
                yaxis: "y2",
              },
              {
                x: series.u,
                y: series.V_ms,
                name: "V bateau",
                type: "scatter",
                mode: "lines",
                line: { color: "#9bd3df", width: 1.8 },
                xaxis: "x",
                yaxis: "y3",
              },
              {
                x: series.u,
                y: A,
                name: "a bateau",
                type: "scatter",
                mode: "lines",
                line: { color: "#c45c26", width: 1.6 },
                xaxis: "x",
                yaxis: "y4",
              },
            ]}
            layout={{
              paper_bgcolor: "rgba(0,0,0,0)",
              plot_bgcolor: "rgba(6,16,24,0.35)",
              font: { color: "#e8f1f4", family: "Source Sans 3", size: 11 },
              margin: { t: 28, r: 48, b: 40, l: 48 },
              height: 520,
              showlegend: true,
              legend: { orientation: "h", y: 1.08 },
              xaxis: {
                title: "u (fraction d'arc)",
                gridcolor: "rgba(255,255,255,0.08)",
                domain: [0, 1],
              },
              yaxis: {
                title: "F (N)",
                gridcolor: "rgba(255,255,255,0.08)",
                domain: [0.78, 1],
              },
              yaxis2: {
                title: "θ (°)",
                gridcolor: "rgba(255,255,255,0.08)",
                domain: [0.52, 0.74],
              },
              yaxis3: {
                title: "V (m/s)",
                gridcolor: "rgba(255,255,255,0.08)",
                domain: [0.26, 0.48],
              },
              yaxis4: {
                title: "a (m/s²)",
                gridcolor: "rgba(255,255,255,0.08)",
                domain: [0, 0.22],
              },
              shapes,
              annotations: showRefs
                ? [
                    {
                      x: 0.4,
                      y: 1,
                      yref: "paper",
                      text: "F_u_peak≈0.40",
                      showarrow: false,
                      font: { size: 10, color: "#9bd3df" },
                    },
                  ]
                : [],
            }}
            config={{ displayModeBar: false, responsive: true }}
            style={{ width: "100%" }}
          />
        </div>
        <div className="panel">
          <BoatSchematic
            nRowers={boat.n_rowers}
            sculling={boat.sculling}
            coxed={boat.coxed}
            thetaDeg={thetaNow}
          />
          <p className="muted" style={{ marginTop: 8 }}>
            geometry_source: {boat.geometry_source} · catch{" "}
            {boat.theta_catch_deg}° → finish {boat.theta_finish_deg}°
          </p>

          <h3 style={{ marginTop: "1rem" }}>Courbe « poisson »</h3>
          <p className="muted">
            ω(θ) cycle complet — asymétrie drive/retour ≈ signature check_factor.
          </p>
          {fish && fish.theta_deg.length ? (
            <Plot
              data={[
                {
                  x: fish.theta_deg,
                  y: fish.theta_dot_deg_s,
                  type: "scatter",
                  mode: "lines",
                  name: "ω(θ)",
                  line: { color: "#3a9bb0", width: 2 },
                },
                ...(fishTheta != null && fishOmega != null
                  ? [
                      {
                        x: [fishTheta],
                        y: [fishOmega],
                        type: "scatter" as const,
                        mode: "markers" as const,
                        name: "curseur u",
                        marker: { color: "#d4c4a8", size: 9 },
                      },
                    ]
                  : []),
              ]}
              layout={{
                paper_bgcolor: "rgba(0,0,0,0)",
                plot_bgcolor: "rgba(6,16,24,0.35)",
                font: { color: "#e8f1f4", family: "Source Sans 3" },
                margin: { t: 16, r: 16, b: 44, l: 52 },
                height: 260,
                showlegend: false,
                xaxis: {
                  title: "θ (°)",
                  gridcolor: "rgba(255,255,255,0.08)",
                  zeroline: true,
                },
                yaxis: {
                  title: "ω (°/s)",
                  gridcolor: "rgba(255,255,255,0.08)",
                  zeroline: true,
                },
              }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: "100%" }}
            />
          ) : (
            <p className="muted">Série poisson absente — relancer /simulate.</p>
          )}
        </div>
      </div>
    </div>
  );
}
