import { useMemo, useState } from "react";
import Plot from "react-plotly.js";
import { useSearchParams } from "react-router-dom";
import {
  ApiError,
  api,
  openReplayStream,
  type ProgressionResult,
  type RameurReview,
} from "../../api";
import { BoatSchematic } from "../../components/BoatSchematic";
import { StatusBadge, classBadgeKind } from "../../components/StatusBadge";
import { useApp } from "../../state";

/**
 * Vue Rameur §3.1 — athlète, pas analyste.
 * BoatSchematic inchangé ; sélection de poste via URL ?seat= + boutons.
 * Courbe force = Plotly (pas StrokeGeometry).
 */
export function RameurView() {
  const { role } = useApp();
  const [params, setParams] = useSearchParams();
  const seat = Math.max(1, Number(params.get("seat") || "1") || 1);
  const [review, setReview] = useState<RameurReview | null>(null);
  const [progression, setProgression] = useState<ProgressionResult | null>(
    null,
  );
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function selectSeat(s: number) {
    const next = new URLSearchParams(params);
    next.set("seat", String(s));
    setParams(next, { replace: true });
  }

  async function loadReview() {
    if (!role) return;
    setLoading(true);
    setError(null);
    try {
      const sess = await api.createSession(role, "2x");
      setSessionId(sess.session_id);
      // Remplit le store (marks) pour progression + jointure haptique
      await openReplayStream(role, {
        boat_class: "2x",
        n_strokes: 12,
        n_discard: 4,
        realtime: false,
        session_id: sess.session_id,
        onFrame: () => {},
      });
      // Deuxième séance légère pour que la tendance multi-séances ait ≥2 points
      const sess2 = await api.createSession(role, "2x");
      await openReplayStream(role, {
        boat_class: "2x",
        n_strokes: 10,
        n_discard: 4,
        realtime: false,
        session_id: sess2.session_id,
        onFrame: () => {},
      });
      // Signaux haptiques sur la séance courante (journal)
      const detail = await api.getSession(role, sess.session_id);
      const strokes = detail.strokes as Array<{ t_utc: string; stroke_index: number }>;
      if (strokes.length >= 3) {
        const mid = strokes[Math.floor(strokes.length / 2)];
        const late = strokes[strokes.length - 2];
        await api.postEvent(role, sess.session_id, {
          source: "haptic_alert",
          tag: "timing",
          transcript: "Signal coup",
          t_utc: mid.t_utc,
        });
        await api.postEvent(role, sess.session_id, {
          source: "haptic_alert",
          tag: "longueur",
          transcript: "Signal coup",
          t_utc: late.t_utc,
        });
      }
      const [rev, prog] = await Promise.all([
        api.rameurReview(role, {
          boat_class: "2x",
          seat,
          n_prev: 10,
          session_id: sess.session_id,
        }),
        api.rameurProgression(role, "2x"),
      ]);
      setReview(rev);
      setProgression(prog);
      if (rev.boat.n_rowers && seat > rev.boat.n_rowers) {
        selectSeat(1);
      }
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  async function reloadSeat(nextSeat: number) {
    selectSeat(nextSeat);
    if (!role || !sessionId) return;
    setLoading(true);
    try {
      const rev = await api.rameurReview(role, {
        boat_class: "2x",
        seat: nextSeat,
        n_prev: 10,
        session_id: sessionId,
      });
      setReview(rev);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  const plotData = useMemo(() => {
    if (!review?.strokes?.length) return [];
    const strokes = review.strokes;
    const traces: Array<Record<string, unknown>> = [];
    strokes.forEach((st, idx) => {
      const isLast = idx === strokes.length - 1;
      traces.push({
        x: st.t_s,
        y: st.handle_force_N,
        type: "scatter",
        mode: "lines",
        name: isLast ? "Dernier coup" : `Coup ${st.stroke_index + 1}`,
        line: {
          color: isLast ? "#3a9bb0" : "rgba(183,201,209,0.35)",
          width: isLast ? 2.5 : 1.2,
        },
        showlegend: isLast || idx === 0,
      });
    });
    // Haptique : marqueurs au pic du coup signalé (si présent dans l'historique)
    const byIdx = new Map(strokes.map((s) => [s.stroke_index, s]));
    const hx: number[] = [];
    const hy: number[] = [];
    const htext: string[] = [];
    for (const ev of review.haptic_events ?? []) {
      const si = ev.nearest_stroke_index;
      if (si == null) continue;
      const st = byIdx.get(si);
      if (!st) continue;
      hx.push(st.t_peak_s);
      hy.push(st.F_peak_N);
      htext.push(ev.tag ? `Vibreur · ${ev.tag}` : "Vibreur");
    }
    if (hx.length) {
      traces.push({
        x: hx,
        y: hy,
        type: "scatter",
        mode: "markers",
        name: "Coups signalés",
        marker: {
          size: 11,
          color: "#c45c26",
          symbol: "diamond",
          line: { color: "#e8f1f4", width: 1 },
        },
        text: htext,
        hoverinfo: "text+x+y",
      });
    }
    return traces;
  }, [review]);

  const nRowers = review?.boat.n_rowers ?? 2;
  const lag = review?.last_phase_lag_ms;
  const pMean = review?.last_P_mean_W;

  return (
    <div className="rameur-view">
      <div className="team-cockpit-head">
        <div>
          <h2>Rameur</h2>
          <p className="muted">
            Ta technique et ta progression — classe 2x
            {sessionId ? ` · séance ${sessionId.slice(0, 8)}…` : ""}
          </p>
        </div>
        <div style={{ display: "flex", gap: "0.4rem", alignItems: "center" }}>
          <StatusBadge kind="sim" />
          {review && (
            <StatusBadge
              kind={classBadgeKind(review.validation.status)}
              label={review.validation.label}
            />
          )}
        </div>
      </div>

      <div className="banner info">
        Écran perso : pas de classement entre rameurs. La force est fiable ;
        la puissance porte un badge <StatusBadge kind="indice" /> distinct de{" "}
        <StatusBadge kind="sim" />.
      </div>

      {error && <div className="banner network">{error}</div>}

      <div className="team-controls" style={{ marginBottom: "1rem" }}>
        <button type="button" disabled={loading} onClick={() => void loadReview()}>
          {loading ? "Chargement…" : "Voir ma séance"}
        </button>
        <span className="muted">
          Point d&apos;entrée : choisis ton poste sur le schéma
        </span>
      </div>

      <div className="grid-2">
        <div className="panel">
          <h3>Ton poste</h3>
          <div style={{ position: "relative" }}>
            <BoatSchematic
              nRowers={nRowers}
              sculling={review?.boat.sculling ?? true}
              coxed={review?.boat.coxed ?? false}
              highlightSeat={seat}
            />
            {/* Hit-targets au-dessus du schéma — BoatSchematic non modifié */}
            <div
              className="rameur-seat-hits"
              style={{
                display: "flex",
                justifyContent: "space-around",
                marginTop: "0.5rem",
                gap: "0.35rem",
              }}
            >
              {Array.from({ length: nRowers }, (_, i) => i + 1).map((s) => (
                <button
                  key={s}
                  type="button"
                  className={s === seat ? undefined : "ghost"}
                  onClick={() => void reloadSeat(s)}
                  disabled={loading}
                >
                  Poste {s}
                  {s === 1 ? " (nage)" : ""}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="panel">
          <h3>Écart avec le rameur de nage</h3>
          <div className="metric">
            <div className="label">Décalage (ms)</div>
            <div className="value">
              {lag == null
                ? "—"
                : `${lag >= 0 ? "+" : ""}${lag.toFixed(0)} ms`}
            </div>
            <div className="target">
              Référence bateau = poste de nage — pas les autres rameurs
            </div>
          </div>
          <div className="metric" style={{ marginTop: "0.75rem" }}>
            <div className="label">
              Puissance moyenne <StatusBadge kind="indice" />
            </div>
            <div className="value">
              {pMean == null ? "—" : `${pMean.toFixed(0)} W`}
            </div>
            <div className="target">
              {review?.power_calibration.message ??
                "En attente de calibration traînée"}
            </div>
          </div>
        </div>
      </div>

      <div className="panel" style={{ marginTop: "1rem" }}>
        <h3>Courbe de force — dernier coup + 10 précédents</h3>
        <p className="muted">
          Forme et pic de ta poignée. Les losanges orange = coups où le
          vibreur a signalé.
        </p>
        {plotData.length === 0 ? (
          <p className="muted">Charge une séance pour afficher la courbe.</p>
        ) : (
          <Plot
            data={plotData as never}
            layout={{
              paper_bgcolor: "rgba(0,0,0,0)",
              plot_bgcolor: "rgba(6,16,24,0.35)",
              font: { color: "#e8f1f4", family: "Source Sans 3" },
              margin: { t: 24, r: 24, b: 48, l: 56 },
              height: 340,
              showlegend: true,
              legend: { orientation: "h" },
              xaxis: {
                title: "Temps dans le coup (s)",
                gridcolor: "rgba(255,255,255,0.08)",
              },
              yaxis: {
                title: "Force (N)",
                gridcolor: "rgba(255,255,255,0.08)",
              },
            }}
            config={{ displayModeBar: false, responsive: true }}
            style={{ width: "100%" }}
          />
        )}
      </div>

      <div className="grid-2" style={{ marginTop: "1rem" }}>
        <div className="panel">
          <h3>
            Progression <StatusBadge kind="indice" />
          </h3>
          <p className="muted">
            Tendance sur plusieurs séances à cadence proche — pas un chiffre
            isolé.
          </p>
          {!progression || progression.points.length === 0 ? (
            <p className="muted">Pas encore assez de séances enregistrées.</p>
          ) : (
            <>
              <Plot
                data={[
                  {
                    x: progression.points.map((p) => p.t_start_utc),
                    y: progression.points.map((p) => p.P_mean_W),
                    type: "scatter",
                    mode: "lines+markers",
                    name: "Puissance (indice)",
                    line: { color: "#d4c4a8", width: 2 },
                    marker: { size: 8, color: "#3a9bb0" },
                  },
                ]}
                layout={{
                  paper_bgcolor: "rgba(0,0,0,0)",
                  plot_bgcolor: "rgba(6,16,24,0.35)",
                  font: { color: "#e8f1f4", family: "Source Sans 3" },
                  margin: { t: 16, r: 16, b: 48, l: 48 },
                  height: 240,
                  showlegend: false,
                  xaxis: { title: "Séance", gridcolor: "rgba(255,255,255,0.08)" },
                  yaxis: {
                    title: "W (indice)",
                    gridcolor: "rgba(255,255,255,0.08)",
                  },
                }}
                config={{ displayModeBar: false, responsive: true }}
                style={{ width: "100%" }}
              />
              {progression.trend ? (
                <p className="muted" style={{ marginTop: "0.5rem" }}>
                  Sur {progression.trend.n_sessions} séances comparables :{" "}
                  {progression.trend.direction === "up" && "en hausse"}
                  {progression.trend.direction === "down" && "en baisse"}
                  {progression.trend.direction === "flat" && "stable"}{" "}
                  (
                  {progression.trend.delta_W >= 0 ? "+" : ""}
                  {progression.trend.delta_W.toFixed(0)} W)
                </p>
              ) : (
                <p className="muted">{progression.note}</p>
              )}
            </>
          )}
        </div>

        <div className="panel">
          <h3>Journal vibreur</h3>
          <p className="muted">
            Coups signalés pendant la séance (même table events que Coach,
            source haptic_alert).
          </p>
          {!review?.haptic_events?.length ? (
            <p className="muted">Aucun signal sur cette séance.</p>
          ) : (
            <ul className="event-timeline">
              {review.haptic_events.map((ev) => (
                <li key={ev.event_id}>
                  <span className="event-chip">
                    <span className="event-chip-t">{ev.t_utc}</span>
                    <span>
                      {ev.tag ?? "signal"}
                      {ev.nearest_stroke_index != null
                        ? ` · coup ${ev.nearest_stroke_index + 1}`
                        : ""}
                    </span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
