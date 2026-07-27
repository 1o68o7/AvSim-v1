/**
 * Courbe « poisson » — ω(θ) cycle complet (brief-visuels §3).
 * Marqueur curseur repéré sur fish.theta_deg (pas series.theta_dot).
 */
import Plot from "react-plotly.js";

import type { FishSeries } from "../api";
import { fishMarkerAtTheta } from "./fishMarker";

export type FishCurvePanelProps = {
  fish?: FishSeries;
  /** θ au curseur u (series poste 0) — repéré sur la courbe poisson. */
  cursorThetaDeg: number;
};

export function FishCurvePanel({ fish, cursorThetaDeg }: FishCurvePanelProps) {
  if (!fish?.theta_deg?.length) {
    return (
      <p className="muted">Série poisson absente — relancer /simulate.</p>
    );
  }

  const marker = fishMarkerAtTheta(fish, cursorThetaDeg);

  return (
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
        ...(marker
          ? [
              {
                x: [marker.theta_deg],
                y: [marker.theta_dot_deg_s],
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
        font: { color: "#e8f1f4", family: "Geist Variable, Inter, sans-serif" },
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
  );
}
