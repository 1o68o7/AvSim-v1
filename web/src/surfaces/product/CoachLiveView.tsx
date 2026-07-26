import { useEffect, useRef, useState } from "react";
import {
  ApiError,
  api,
  openReplayStream,
  type CrewSeatLive,
  type ReplayFrame,
  type SyncAlert,
} from "../../api";
import { StatusBadge } from "../../components/StatusBadge";
import { useApp } from "../../state";

type SeatRow = CrewSeatLive;

export function CoachLiveView() {
  const { role } = useApp();
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [crew, setCrew] = useState<SeatRow[]>([]);
  const [sync, setSync] = useState<SyncAlert | null>(null);
  const [checkFactor, setCheckFactor] = useState<number | null>(null);
  const [stroke, setStroke] = useState<number | null>(null);
  const [status, setStatus] = useState<"idle" | "running" | "ended" | "error">(
    "idle",
  );
  const [error, setError] = useState<string | null>(null);
  const [tag, setTag] = useState("longueur");
  const [transcript, setTranscript] = useState("");
  const [annotating, setAnnotating] = useState(false);
  const [lastEventId, setLastEventId] = useState<string | null>(null);
  const [recording, setRecording] = useState(false);
  const abortRef = useRef<AbortController | null>(null);
  const mediaRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  useEffect(() => {
    return () => {
      abortRef.current?.abort();
      mediaRef.current?.stop();
    };
  }, []);

  async function start() {
    if (!role) return;
    abortRef.current?.abort();
    const ac = new AbortController();
    abortRef.current = ac;
    setError(null);
    setCrew([]);
    setSync(null);
    setStroke(null);
    setLastEventId(null);
    setStatus("running");
    try {
      const sess = await api.createSession(role, "2x");
      setSessionId(sess.session_id);
      await openReplayStream(role, {
        boat_class: "2x",
        n_strokes: 12,
        n_discard: 4,
        realtime: true,
        session_id: sess.session_id,
        signal: ac.signal,
        onFrame: (frame: ReplayFrame) => {
          if (frame.kind === "stroke") {
            setStroke(frame.stroke_index);
            setCrew(frame.crew ?? []);
            setSync(frame.sync_alert ?? null);
            setCheckFactor(
              frame.check_factor ?? frame.energy?.check_factor ?? null,
            );
          } else if (frame.kind === "end") {
            setStatus("ended");
          }
        },
      });
      if (!ac.signal.aborted) setStatus((s) => (s === "running" ? "ended" : s));
    } catch (e) {
      if ((e as Error).name === "AbortError") return;
      setStatus("error");
      setError(e instanceof ApiError ? e.message : String(e));
    }
  }

  function stop() {
    abortRef.current?.abort();
    abortRef.current = null;
    setStatus("idle");
  }

  async function postAnnotation(audio_ref: string | null) {
    if (!role || !sessionId) return;
    setAnnotating(true);
    try {
      const ev = await api.postEvent(role, sessionId, {
        source: "coach_voice",
        audio_ref,
        transcript: transcript.trim() || null,
        tag: tag || null,
      });
      setLastEventId(ev.event_id);
      setTranscript("");
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    } finally {
      setAnnotating(false);
    }
  }

  async function toggleVoice() {
    if (recording) {
      mediaRef.current?.stop();
      setRecording(false);
      return;
    }
    if (!navigator.mediaDevices?.getUserMedia) {
      await postAnnotation(null);
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const rec = new MediaRecorder(stream);
      chunksRef.current = [];
      rec.ondataavailable = (e) => {
        if (e.data.size) chunksRef.current.push(e.data);
      };
      rec.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        // audio_ref = référence locale (pas d'upload fichier en prototype)
        void postAnnotation(`blob:coach_voice/${Date.now()}.webm`);
      };
      mediaRef.current = rec;
      rec.start();
      setRecording(true);
    } catch {
      // Pas de micro — annotation texte seule
      await postAnnotation(null);
    }
  }

  return (
    <div className="coach-live">
      <div className="team-cockpit-head">
        <div>
          <h2>Coach live</h2>
          <p className="muted">
            Canal B · densité par poste · classe 2x ·{" "}
            {sessionId ? `séance ${sessionId.slice(0, 8)}…` : "pas de séance"}
          </p>
        </div>
        <StatusBadge kind="sim" />
      </div>

      <div className="banner info">
        Flux SSE rejeu — jamais présenté comme Mesuré. Décalage affiché brut
        (Mode D absent).
      </div>

      <div className="team-controls" style={{ marginBottom: "1rem" }}>
        {status === "running" ? (
          <button type="button" onClick={stop}>
            Arrêter
          </button>
        ) : (
          <button type="button" onClick={() => void start()}>
            Démarrer rejeu 2x
          </button>
        )}
        <span className="muted">
          {status === "running" &&
            `Coup ${stroke == null ? "…" : stroke + 1}`}
          {status === "ended" && "Séance terminée — annotations conservées"}
          {status === "error" && (error ?? "Erreur")}
          {status === "idle" && "Prêt"}
        </span>
      </div>

      <div className="coach-seat-grid">
        {crew.length === 0 && (
          <p className="muted">En attente des coups…</p>
        )}
        {crew.map((s) => {
          const alert = sync?.seat === s.seat;
          return (
            <div
              key={s.seat}
              className={`coach-seat${alert ? " alert" : ""}`}
            >
              <div className="coach-seat-title">Poste {s.seat}</div>
              <div className="coach-seat-row">
                <span>Force pic</span>
                <strong>{s.F_peak_N.toFixed(0)} N</strong>
              </div>
              <div className="coach-seat-row">
                <span>Timing</span>
                <strong>
                  {s.timing_ms >= 0 ? "+" : ""}
                  {s.timing_ms.toFixed(0)} ms
                </strong>
              </div>
              <div className="coach-seat-row">
                <span>P moy.</span>
                <strong>{s.P_mean_W.toFixed(0)} W</strong>
              </div>
              {alert && (
                <div className="coach-seat-flag">Plus grand décalage (brut)</div>
              )}
            </div>
          );
        })}
      </div>

      <div className="team-controls" style={{ marginTop: "0.75rem" }}>
        <span className="muted">
          check_factor bateau :{" "}
          <strong>
            {checkFactor == null ? "—" : checkFactor.toFixed(2)} m/s
          </strong>{" "}
          (Simulé)
        </span>
      </div>
      {sync && (
        <p className="muted" style={{ marginTop: "0.5rem" }}>
          {sync.note}
        </p>
      )}

      <div className="panel" style={{ marginTop: "1.25rem" }}>
        <h3>Annotation vocale → table events</h3>
        <p className="muted">
          Horodatage à la seconde (horloge navigateur). Schéma : event_id,
          t_utc, source, audio_ref, transcript, tag, session_id.
        </p>
        <div className="field-grid" style={{ maxHeight: "none" }}>
          <label className="field-row">
            <span>Tag</span>
            <select value={tag} onChange={(e) => setTag(e.target.value)}>
              <option value="longueur">longueur</option>
              <option value="cadence">cadence</option>
              <option value="relax">relax</option>
              <option value="autre">autre</option>
            </select>
            <span />
          </label>
          <label className="field-row">
            <span>Transcript</span>
            <input
              value={transcript}
              onChange={(e) => setTranscript(e.target.value)}
              placeholder="optionnel — ordre dit à voix haute"
            />
            <span />
          </label>
        </div>
        <div className="team-controls" style={{ marginTop: "0.75rem" }}>
          <button
            type="button"
            disabled={!sessionId || annotating}
            onClick={() => void toggleVoice()}
          >
            {recording ? "Stop + enregistrer" : "Annoter (voix / marqueur)"}
          </button>
          <button
            type="button"
            className="ghost"
            disabled={!sessionId || annotating || recording}
            onClick={() => void postAnnotation(null)}
          >
            Marqueur sans audio
          </button>
          {lastEventId && (
            <span className="muted">Dernier event {lastEventId.slice(0, 8)}…</span>
          )}
        </div>
      </div>
    </div>
  );
}
