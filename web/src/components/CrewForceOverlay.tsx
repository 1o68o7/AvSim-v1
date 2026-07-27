/**
 * Nesting forces équipage — F vs u (brief-visuels-coaching §2).
 * Pics alignés = synchro ; décalage visible sans chiffre.
 */
import Plot from "react-plotly.js";

import type { DriveSeries } from "../api";

export type { DriveSeries };

export type CrewForceOverlayProps = {
  seats: Array<{ seat: number; drive?: DriveSeries }>;
  height?: number;
  emptyMessage?: string;
};

const SEAT_COLORS = [
  "#3a9bb0",
  "#d4c4a8",
  "#9bd3df",
  "#c45c26",
  "#2f7d4a",
  "#b8860b",
  "#7a9bb0",
  "#e8f1f4",
];

export function CrewForceOverlay({
  seats,
  height = 280,
  emptyMessage = "Séries drive absentes — relancer /simulate.",
}: CrewForceOverlayProps) {
  const nestTraces = seats
    .filter((r) => r.drive && r.drive.u.length > 0)
    .map((r, i) => ({
      x: r.drive!.u,
      y: r.drive!.handle_force_N,
      name: `Poste ${r.seat}`,
      type: "scatter" as const,
      mode: "lines" as const,
      line: { color: SEAT_COLORS[i % SEAT_COLORS.length], width: 2 },
    }));

  if (!nestTraces.length) {
    return <p className="muted">{emptyMessage}</p>;
  }

  return (
    <Plot
      data={nestTraces as never}
      layout={{
        paper_bgcolor: "rgba(0,0,0,0)",
        plot_bgcolor: "rgba(6,16,24,0.35)",
        font: { color: "#e8f1f4", family: "Source Sans 3" },
        margin: { t: 20, r: 16, b: 44, l: 48 },
        height,
        showlegend: true,
        legend: { orientation: "h" },
        xaxis: {
          title: "u",
          gridcolor: "rgba(255,255,255,0.08)",
        },
        yaxis: {
          title: "F (N)",
          gridcolor: "rgba(255,255,255,0.08)",
        },
      }}
      config={{ displayModeBar: false, responsive: true }}
      style={{ width: "100%" }}
    />
  );
}
