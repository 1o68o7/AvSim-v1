import Plot from "react-plotly.js";
import { BoatSchematic } from "../../components/BoatSchematic";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { StrokeLengthBarStack } from "../../components/StrokeLengthBar";
import { useApp } from "../../state";

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

export function CrewView() {
  const { result } = useApp();

  if (!result) {
    return (
      <div className="panel">
        <h2>Équipage</h2>
        <p className="muted">Aucune simulation chargée.</p>
      </div>
    );
  }

  const { crew, boat, validation } = result;
  const mismatch = crew.length !== boat.n_rowers;

  const nestTraces = crew
    .filter((r) => r.drive && r.drive.u.length > 0)
    .map((r, i) => ({
      x: r.drive!.u,
      y: r.drive!.handle_force_N,
      name: `Poste ${r.seat}`,
      type: "scatter" as const,
      mode: "lines" as const,
      line: { color: SEAT_COLORS[i % SEAT_COLORS.length], width: 2 },
    }));

  return (
    <div>
      <div className="topbar">
        <div>
          <h2>Équipage</h2>
          <p className="muted">
            Détail par poste — <StatusBadge kind="sim" />
          </p>
        </div>
        <StatusBadge
          kind={classBadgeKind(validation.status)}
          label={validation.label}
        />
      </div>
      {validation.status === "beta" && (
        <div className="banner beta">Classe bêta — non calibrée</div>
      )}
      {mismatch && (
        <div className="banner network">
          Incohérence : {crew.length} lignes ≠ n_rowers={boat.n_rowers} (garde-fou
          chargeur).
        </div>
      )}

      <div className="grid-2">
        <div className="panel">
          <table className="data">
            <thead>
              <tr>
                <th>Poste</th>
                <th>phase_offset (ms)</th>
                <th>E_handle (J)</th>
                <th>P_mean (W)</th>
              </tr>
            </thead>
            <tbody>
              {crew.map((r) => (
                <tr key={r.seat}>
                  <td>{r.seat}</td>
                  <td>{r.phase_offset_ms.toFixed(1)}</td>
                  <td>{r.E_handle_J.toFixed(1)}</td>
                  <td>{r.P_mean_W.toFixed(1)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="panel">
          <BoatSchematic
            nRowers={boat.n_rowers}
            sculling={boat.sculling}
            coxed={boat.coxed}
          />
        </div>
      </div>

      <div className="grid-2" style={{ marginTop: "0.8rem" }}>
        <div className="panel">
          <h3>Longueur de coup</h3>
          <StrokeLengthBarStack
            bars={crew.map((r) => ({ seat: r.seat, bar: r.stroke_bar }))}
          />
        </div>
        <div className="panel">
          <h3>Nesting — forces superposées</h3>
          <p className="muted">
            Pics alignés = synchro ; décalage visible sans chiffre. Axe u
            (fraction d&apos;arc).
          </p>
          {nestTraces.length ? (
            <Plot
              data={nestTraces as never}
              layout={{
                paper_bgcolor: "rgba(0,0,0,0)",
                plot_bgcolor: "rgba(6,16,24,0.35)",
                font: { color: "#e8f1f4", family: "Source Sans 3" },
                margin: { t: 20, r: 16, b: 44, l: 48 },
                height: 280,
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
          ) : (
            <p className="muted">Séries drive absentes — relancer /simulate.</p>
          )}
        </div>
      </div>
    </div>
  );
}
