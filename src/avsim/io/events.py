"""Table `events` — brief personas §6 / interface §3.3.

Précision horodatage : seconde (horloge téléphone). Pas de synchro dédiée.
Stockage processus (prototype) — pas une base durable.
"""
from __future__ import annotations

import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Literal

EventSource = Literal["coach_voice"]


def utc_now_second() -> str:
    """ISO-8601 à la seconde près (UTC)."""
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


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
    energy: dict[str, float] = field(default_factory=dict)

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


class EventStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._sessions: dict[str, Session] = {}

    def create_session(self, boat_class: str) -> Session:
        sid = str(uuid.uuid4())
        sess = Session(
            session_id=sid,
            boat_class=boat_class,
            t_start_utc=utc_now_second(),
        )
        with self._lock:
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
