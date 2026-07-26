import { BoatSchematic } from "../../components/BoatSchematic";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { useEnsureSimulate } from "../../hooks/useEnsureSimulate";

export function CrewView() {
  const { result, busy, networkError, retry, selected, boatClass } =
    useEnsureSimulate();

  const status = result?.validation ?? selected;
  const isBeta = status?.status === "beta";

  return (
    <div>
      <div className="topbar">
        <div>
          <h2>Équipage</h2>
          <p className="muted">
            Détail par poste — <StatusBadge kind="sim" /> · /api/simulate
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
        const { crew, boat, validation } = result;
        const mismatch = crew.length !== boat.n_rowers;
        return (
          <>
            {mismatch && (
              <div className="banner network">
                Incohérence : {crew.length} lignes ≠ n_rowers={boat.n_rowers}{" "}
                (garde-fou chargeur).
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
                <p className="muted" style={{ marginTop: 8 }}>
                  Champs API <code>crew[]</code> — validation{" "}
                  {validation.label}
                </p>
              </div>
              <div className="panel">
                <BoatSchematic
                  nRowers={boat.n_rowers}
                  sculling={boat.sculling}
                  coxed={boat.coxed}
                />
              </div>
            </div>
          </>
        );
      })()}
    </div>
  );
}
