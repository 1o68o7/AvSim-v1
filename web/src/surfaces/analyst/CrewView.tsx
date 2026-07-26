import { BoatSchematic } from "../../components/BoatSchematic";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { useApp } from "../../state";

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
    </div>
  );
}
