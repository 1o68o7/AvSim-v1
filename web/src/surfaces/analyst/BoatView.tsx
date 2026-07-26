import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ApiError, api } from "../../api";
import { BoatSchematic } from "../../components/BoatSchematic";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { useApp, useSelectedClass } from "../../state";

type AnnField = {
  v: unknown;
  min?: number;
  max?: number;
  src?: string | null;
  sourced?: boolean;
};

function flattenAnnotated(
  node: unknown,
  prefix = "",
): Array<{ key: string; field: AnnField }> {
  if (!node || typeof node !== "object") return [];
  const obj = node as Record<string, unknown>;
  if ("v" in obj && ("sourced" in obj || "src" in obj)) {
    return [{ key: prefix, field: obj as AnnField }];
  }
  const out: Array<{ key: string; field: AnnField }> = [];
  for (const [k, v] of Object.entries(obj)) {
    if (k === "hull_ref" || k === "meta") continue;
    const p = prefix ? `${prefix}.${k}` : k;
    out.push(...flattenAnnotated(v, p));
  }
  return out;
}

export function BoatView() {
  const nav = useNavigate();
  const {
    role,
    boatClass,
    setBoatClass,
    classes,
    setClasses,
    setResult,
    busy,
    setBusy,
    networkError,
    setNetworkError,
  } = useApp();
  const selected = useSelectedClass();
  const [moulds, setMoulds] = useState<Array<Record<string, unknown>>>([]);
  const [builder, setBuilder] = useState<string>("");
  const [mould, setMould] = useState<string>("");
  const [annotated, setAnnotated] = useState<unknown>(null);
  const [loadingParams, setLoadingParams] = useState(false);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    if (!role) return;
    api
      .classes(role)
      .then((r) => {
        setClasses(r.classes);
        setNetworkError(null);
      })
      .catch((e: ApiError) => setNetworkError(e.message));
  }, [role, setClasses, setNetworkError]);

  useEffect(() => {
    if (!role) return;
    api
      .hulls(role, boatClass)
      .then((r) => setMoulds(r.moulds))
      .catch((e: ApiError) => setNetworkError(e.message));
  }, [role, boatClass, setNetworkError]);

  useEffect(() => {
    if (!role || role !== "analyst") return;
    setLoadingParams(true);
    api
      .params(role, boatClass, builder || null, mould || null)
      .then((r) => {
        setAnnotated(r.annotated);
        setNetworkError(null);
      })
      .catch((e: ApiError) => setNetworkError(e.message))
      .finally(() => setLoadingParams(false));
  }, [role, boatClass, builder, mould, setNetworkError]);

  useEffect(() => {
    if (!busy || !startedAt) return;
    const id = window.setInterval(() => {
      setElapsed((Date.now() - startedAt) / 1000);
    }, 200);
    return () => clearInterval(id);
  }, [busy, startedAt]);

  const fields = useMemo(
    () => flattenAnnotated(annotated).slice(0, 80),
    [annotated],
  );

  const run = async () => {
    if (!role) return;
    setBusy(true);
    setStartedAt(Date.now());
    setElapsed(0);
    try {
      const res = await api.simulate(role, {
        boat_class: boatClass,
        hull_builder: builder || null,
        hull_mould: mould || null,
        n_strokes: 6,
        n_discard: 2,
      });
      setResult(res);
      setNetworkError(null);
      nav("/analyst/coup");
    } catch (e) {
      setNetworkError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setBusy(false);
      setStartedAt(null);
    }
  };

  const resetHull = () => {
    setBuilder("");
    setMould("");
  };

  return (
    <div>
      <div className="topbar">
        <div>
          <h2>Bateau</h2>
          <p className="muted">Configuration à simuler — toujours <StatusBadge kind="sim" /></p>
        </div>
        {selected && (
          <StatusBadge kind={classBadgeKind(selected.status)} label={selected.label} />
        )}
      </div>

      {selected?.status === "beta" && (
        <div className="banner beta">
          Classe <strong>{boatClass}</strong> en test de fumée seulement — non
          calibrée (`test_class_scaling.py` absent). Ne pas la traiter à égalité
          avec 8+ / 1x.
        </div>
      )}
      {networkError && (
        <div className="banner network">
          {networkError}{" "}
          <button type="button" className="ghost" onClick={() => setNetworkError(null)}>
            Fermer
          </button>
        </div>
      )}

      <div className="grid-2">
        <div className="panel">
          <label className="muted">Classe</label>
          {classes.length === 0 ? (
            <div className="skeleton" style={{ width: "100%", marginTop: 8 }} />
          ) : (
            <select
              value={boatClass}
              onChange={(e) => {
                setBoatClass(e.target.value);
                setResult(null);
                resetHull();
              }}
              style={{ width: "100%", marginTop: 6, padding: "0.45rem" }}
            >
              {classes.map((c) => (
                <option key={c.code} value={c.code}>
                  {c.code} — {c.label} ({c.n_rowers}p
                  {c.sculling ? ", couple" : ", pointe"}
                  {c.coxed ? ", barré" : ""})
                </option>
              ))}
            </select>
          )}

          <div style={{ marginTop: "0.9rem" }}>
            <label className="muted">Constructeur / moule (hull_ref)</label>
            <select
              value={builder && mould ? `${builder}||${mould}` : ""}
              onChange={(e) => {
                const v = e.target.value;
                if (!v) {
                  resetHull();
                  return;
                }
                const [b, m] = v.split("||");
                setBuilder(b);
                setMould(m);
              }}
              style={{ width: "100%", marginTop: 6, padding: "0.45rem" }}
            >
              <option value="">composite (médiane) — geometry_source: composite</option>
              {moulds.map((m) => (
                <option
                  key={`${m.builder}-${m.mould}`}
                  value={`${m.builder}||${m.mould}`}
                >
                  {String(m.builder)} / {String(m.mould)}
                </option>
              ))}
            </select>
          </div>

          <div style={{ marginTop: "1rem", display: "flex", gap: "0.5rem" }}>
            <button type="button" onClick={run} disabled={busy || !classes.length}>
              {busy ? "Simulation…" : "Lancer une simulation"}
            </button>
            <button type="button" className="ghost" onClick={resetHull} disabled={busy}>
              Réinitialiser coque
            </button>
          </div>
          {busy && (
            <div className="banner info">
              Calcul en cours — {elapsed.toFixed(1)} s
              {elapsed > 5
                ? " (souvent 10–60 s selon la classe ; pas instantané)"
                : ""}
            </div>
          )}
        </div>

        <div className="panel">
          <BoatSchematic
            nRowers={selected?.n_rowers ?? 0}
            sculling={selected?.sculling ?? false}
            coxed={selected?.coxed ?? false}
            thetaDeg={0}
          />
        </div>
      </div>

      <div className="panel" style={{ marginTop: "1rem" }}>
        <h3>Paramètres (sources YAML)</h3>
        <p className="muted">
          Champ sans <code>src</code> → <span className="src-missing">non sourcé</span>
        </p>
        {loadingParams ? (
          <div className="skeleton" style={{ height: 120, marginTop: 8 }} />
        ) : (
          <div className="field-grid">
            {fields.map(({ key, field }) => (
              <div className="field-row" key={key}>
                <span>{key}</span>
                <span>{String(field.v)}</span>
                <span className={field.sourced ? "src-ok" : "src-missing"}>
                  {field.sourced ? `src:${field.src}` : "non sourcé"}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
