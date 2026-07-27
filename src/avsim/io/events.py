"""Table `events` — brief personas §6 / interface §3.3.

Précision horodatage : seconde (horloge téléphone). Pas de synchro dédiée.

Persistance : SQLite local (stdlib), cohérent avec l'approche tout-local
du projet. Variable d'environnement ``AVSIM_EVENTS_DB`` (défaut
``data/avsim_events.sqlite``). L'interface ``EventStore`` (create_session,
add_stroke_mark, add_event, …) est inchangée.

**Limite Render (doc officielle Free, vérifiée)** — les web services Free
ont un *ephemeral filesystem* : tout fichier local (y compris SQLite) est
**perdu** à chaque redeploy, restart, ou spin-down idle (15 min sans
trafic). Les Free web services **ne peuvent pas** attacher de persistent
disk. Donc SQLite ici = survie au redémarrage de process en local / sur
disque réel ; **ce n'est pas une persistance de production sur Render
Free**. Pour durer en prod Render : instance payante + disk, ou Render
Postgres.
"""
from __future__ import annotations

import json
import os
import sqlite3
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal

# Champ extensible — valeurs connues aujourd'hui ; d'autres sources possibles.
EventSource = Literal["coach_voice", "haptic_alert"]


def utc_now_second() -> str:
    """ISO-8601 à la seconde près (UTC)."""
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def default_db_path() -> Path:
    env = os.environ.get("AVSIM_EVENTS_DB", "").strip()
    if env:
        return Path(env).expanduser()
    return Path("data") / "avsim_events.sqlite"


@dataclass
class Event:
    event_id: str
    t_utc: str
    source: str
    audio_ref: str | None
    transcript: str | None
    tag: str | None
    session_id: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class StrokeMark:
    """Repère de jointure temporelle coup ↔ events (hors schéma events)."""
    stroke_index: int
    t_utc: str
    cadence_spm: float
    v_ms: float
    check_factor: float
    arc_deg: float = 0.0  # longueur d'arc (θ_catch − θ_finish) réalisée
    phase_lag_ms: float = 0.0  # |décalage| max vs médiane d'attaque
    energy: dict[str, float] = field(default_factory=dict)
    # Barres longueur de coup (§1) — une par poste, pour Coach Replay
    stroke_bars: list[dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Session:
    session_id: str
    boat_class: str
    t_start_utc: str
    source: str = "simulated"
    strokes: list[StrokeMark] = field(default_factory=list)
    events: list[Event] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "session_id": self.session_id,
            "boat_class": self.boat_class,
            "t_start_utc": self.t_start_utc,
            "source": self.source,
            "n_strokes": len(self.strokes),
            "n_events": len(self.events),
            "strokes": [s.to_dict() for s in self.strokes],
            "events": [e.to_dict() for e in self.events],
        }


_SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
    session_id   TEXT PRIMARY KEY,
    boat_class   TEXT NOT NULL,
    t_start_utc  TEXT NOT NULL,
    source       TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS stroke_marks (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id     TEXT NOT NULL REFERENCES sessions(session_id),
    stroke_index   INTEGER NOT NULL,
    t_utc          TEXT NOT NULL,
    cadence_spm    REAL NOT NULL,
    v_ms           REAL NOT NULL,
    check_factor   REAL NOT NULL,
    arc_deg        REAL NOT NULL DEFAULT 0,
    phase_lag_ms   REAL NOT NULL DEFAULT 0,
    energy_json    TEXT NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS events (
    event_id    TEXT PRIMARY KEY,
    session_id  TEXT NOT NULL REFERENCES sessions(session_id),
    t_utc       TEXT NOT NULL,
    source      TEXT NOT NULL,
    audio_ref   TEXT,
    transcript  TEXT,
    tag         TEXT
);
CREATE INDEX IF NOT EXISTS idx_strokes_session ON stroke_marks(session_id);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
"""


class EventStore:
    """Cache mémoire write-through + SQLite (survit à un redémarrage process)."""

    def __init__(self, path: Path | str | None = None) -> None:
        self._lock = threading.Lock()
        self._sessions: dict[str, Session] = {}
        self._path = Path(path) if path is not None else default_db_path()
        self._conn: sqlite3.Connection | None = None
        self._open(self._path)

    @property
    def path(self) -> Path:
        return self._path

    def reopen(self, path: Path | str | None = None) -> None:
        """Recharge depuis un autre fichier (tests / reconfig)."""
        with self._lock:
            self._close_unlocked()
            self._open(Path(path) if path is not None else default_db_path())

    def _close_unlocked(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None
        self._sessions = {}

    def _open(self, path: Path) -> None:
        self._path = path
        self._path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(
            str(self._path),
            check_same_thread=False,
            isolation_level=None,  # autocommit ; on wrappe en BEGIN
        )
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.executescript(_SCHEMA)
        self._conn = conn
        self._sessions = self._load_all(conn)

    def _conn_required(self) -> sqlite3.Connection:
        if self._conn is None:
            raise RuntimeError("EventStore fermé")
        return self._conn

    def _load_all(self, conn: sqlite3.Connection) -> dict[str, Session]:
        sessions: dict[str, Session] = {}
        for row in conn.execute(
            "SELECT session_id, boat_class, t_start_utc, source "
            "FROM sessions ORDER BY t_start_utc"
        ):
            sessions[row["session_id"]] = Session(
                session_id=row["session_id"],
                boat_class=row["boat_class"],
                t_start_utc=row["t_start_utc"],
                source=row["source"],
            )
        for row in conn.execute(
            "SELECT session_id, stroke_index, t_utc, cadence_spm, v_ms, "
            "check_factor, arc_deg, phase_lag_ms, energy_json "
            "FROM stroke_marks ORDER BY id"
        ):
            sess = sessions.get(row["session_id"])
            if sess is None:
                continue
            energy = json.loads(row["energy_json"] or "{}")
            sess.strokes.append(
                StrokeMark(
                    stroke_index=int(row["stroke_index"]),
                    t_utc=row["t_utc"],
                    cadence_spm=float(row["cadence_spm"]),
                    v_ms=float(row["v_ms"]),
                    check_factor=float(row["check_factor"]),
                    arc_deg=float(row["arc_deg"]),
                    phase_lag_ms=float(row["phase_lag_ms"]),
                    energy={str(k): float(v) for k, v in energy.items()},
                )
            )
        for row in conn.execute(
            "SELECT event_id, session_id, t_utc, source, audio_ref, "
            "transcript, tag FROM events ORDER BY t_utc, event_id"
        ):
            sess = sessions.get(row["session_id"])
            if sess is None:
                continue
            sess.events.append(
                Event(
                    event_id=row["event_id"],
                    t_utc=row["t_utc"],
                    source=row["source"],
                    audio_ref=row["audio_ref"],
                    transcript=row["transcript"],
                    tag=row["tag"],
                    session_id=row["session_id"],
                )
            )
        return sessions

    def create_session(self, boat_class: str) -> Session:
        sid = str(uuid.uuid4())
        sess = Session(
            session_id=sid,
            boat_class=boat_class,
            t_start_utc=utc_now_second(),
        )
        with self._lock:
            conn = self._conn_required()
            conn.execute("BEGIN")
            try:
                conn.execute(
                    "INSERT INTO sessions "
                    "(session_id, boat_class, t_start_utc, source) "
                    "VALUES (?, ?, ?, ?)",
                    (sess.session_id, sess.boat_class, sess.t_start_utc, sess.source),
                )
                conn.execute("COMMIT")
            except Exception:
                conn.execute("ROLLBACK")
                raise
            self._sessions[sid] = sess
        return sess

    def get(self, session_id: str) -> Session | None:
        with self._lock:
            return self._sessions.get(session_id)

    def list_sessions(self) -> list[dict[str, Any]]:
        with self._lock:
            return [
                {
                    "session_id": s.session_id,
                    "boat_class": s.boat_class,
                    "t_start_utc": s.t_start_utc,
                    "source": s.source,
                    "n_strokes": len(s.strokes),
                    "n_events": len(s.events),
                }
                for s in self._sessions.values()
            ]

    def add_stroke_mark(self, session_id: str, mark: StrokeMark) -> StrokeMark:
        with self._lock:
            sess = self._sessions.get(session_id)
            if sess is None:
                raise KeyError(session_id)
            conn = self._conn_required()
            conn.execute("BEGIN")
            try:
                conn.execute(
                    "INSERT INTO stroke_marks ("
                    "session_id, stroke_index, t_utc, cadence_spm, v_ms, "
                    "check_factor, arc_deg, phase_lag_ms, energy_json"
                    ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        session_id,
                        int(mark.stroke_index),
                        mark.t_utc,
                        float(mark.cadence_spm),
                        float(mark.v_ms),
                        float(mark.check_factor),
                        float(mark.arc_deg),
                        float(mark.phase_lag_ms),
                        json.dumps(mark.energy or {}),
                    ),
                )
                conn.execute("COMMIT")
            except Exception:
                conn.execute("ROLLBACK")
                raise
            sess.strokes.append(mark)
            return mark

    def add_event(
        self,
        session_id: str,
        *,
        source: str = "coach_voice",
        audio_ref: str | None = None,
        transcript: str | None = None,
        tag: str | None = None,
        t_utc: str | None = None,
    ) -> Event:
        with self._lock:
            sess = self._sessions.get(session_id)
            if sess is None:
                raise KeyError(session_id)
            ev = Event(
                event_id=str(uuid.uuid4()),
                t_utc=t_utc or utc_now_second(),
                source=source,
                audio_ref=audio_ref,
                transcript=transcript,
                tag=tag,
                session_id=session_id,
            )
            conn = self._conn_required()
            conn.execute("BEGIN")
            try:
                conn.execute(
                    "INSERT INTO events ("
                    "event_id, session_id, t_utc, source, audio_ref, "
                    "transcript, tag"
                    ") VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (
                        ev.event_id,
                        ev.session_id,
                        ev.t_utc,
                        ev.source,
                        ev.audio_ref,
                        ev.transcript,
                        ev.tag,
                    ),
                )
                conn.execute("COMMIT")
            except Exception:
                conn.execute("ROLLBACK")
                raise
            sess.events.append(ev)
            return ev

    def nearest_stroke_index(self, session_id: str, t_utc: str) -> int | None:
        """Jointure par proximité temporelle (précision seconde)."""
        with self._lock:
            sess = self._sessions.get(session_id)
            if sess is None or not sess.strokes:
                return None
            target = datetime.fromisoformat(t_utc)
            best_i = 0
            best_d = None
            for i, m in enumerate(sess.strokes):
                d = abs(
                    (datetime.fromisoformat(m.t_utc) - target).total_seconds()
                )
                if best_d is None or d < best_d:
                    best_d = d
                    best_i = m.stroke_index
            return best_i


STORE = EventStore()
