"""Routes téléphone DataR0w — préfixe /datarow, sans OAuth / rôle Analyste."""
from __future__ import annotations

import json
import secrets
import threading
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/datarow", tags=["datarow-phone"])

_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_TTL = timedelta(hours=12)
_lock = threading.Lock()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _new_code() -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(6))


def _new_id() -> str:
    return f"s{int(_now().timestamp() * 1000)}"


@dataclass
class PhoneSession:
    id: str
    code: str
    created_at: datetime
    last_sample: dict[str, Any] | None = None
    samples: list[dict[str, Any]] = field(default_factory=list)
    notes: list[dict[str, Any]] = field(default_factory=list)
    meta: dict[str, Any] = field(default_factory=dict)

    def expired(self, now: datetime | None = None) -> bool:
        t = now or _now()
        return t - self.created_at > _TTL


_SESSIONS: dict[str, PhoneSession] = {}
_BY_CODE: dict[str, str] = {}


def reset_store() -> None:
    """Tests uniquement."""
    with _lock:
        _SESSIONS.clear()
        _BY_CODE.clear()


def _get_fresh(sid: str) -> PhoneSession:
    s = _SESSIONS.get(sid)
    if s is None or s.expired():
        if s is not None:
            _forget(s)
        raise HTTPException(404, "séance inconnue ou expirée")
    return s


def _forget(s: PhoneSession) -> None:
    _SESSIONS.pop(s.id, None)
    if _BY_CODE.get(s.code) == s.id:
        _BY_CODE.pop(s.code, None)


class CreateBody(BaseModel):
    id: str | None = None
    code: str | None = None
    meta: dict[str, Any] = Field(default_factory=dict)


@router.post("/sessions")
def create_session(body: CreateBody | None = None) -> dict[str, str]:
    body = body or CreateBody()
    with _lock:
        sid = (body.id or "").strip() or _new_id()
        raw_code = (body.code or "").strip().upper()
        code = raw_code if len(raw_code) == 6 else _new_code()
        while code in _BY_CODE and _BY_CODE[code] != sid:
            if raw_code:
                raise HTTPException(409, "code déjà utilisé")
            code = _new_code()
        existing = _SESSIONS.get(sid)
        if existing is not None and not existing.expired():
            existing.code = code
            existing.meta.update(body.meta)
            _BY_CODE[code] = sid
            return {"id": sid, "code": code}
        sess = PhoneSession(
            id=sid,
            code=code,
            created_at=_now(),
            meta=dict(body.meta),
        )
        _SESSIONS[sid] = sess
        _BY_CODE[code] = sid
        return {"id": sid, "code": code}


@router.post("/sessions/{sid}/tick")
async def tick(sid: str, request: Request) -> dict[str, bool]:
    raw = (await request.body()).decode("utf-8").strip()
    if not raw:
        raise HTTPException(400, "body vide")
    try:
        sample = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(400, "JSON invalide") from exc
    if not isinstance(sample, dict):
        raise HTTPException(400, "objet JSON attendu")
    with _lock:
        sess = _get_fresh(sid)
        sess.last_sample = sample
        sess.samples.append(sample)
        if len(sess.samples) > 50_000:
            sess.samples = sess.samples[-40_000:]
    return {"ok": True}


@router.get("/sessions/by-code/{code}")
def by_code(code: str) -> dict[str, Any]:
    needle = code.strip().upper()
    with _lock:
        sid = _BY_CODE.get(needle)
        if sid is None:
            raise HTTPException(404, "code inconnu")
        sess = _SESSIONS.get(sid)
        if sess is None or sess.expired():
            if sess is not None:
                _forget(sess)
            raise HTTPException(404, "séance expirée")
        return {
            "id": sess.id,
            "code": sess.code,
            "created_at": sess.created_at.isoformat(),
            "expires_at": (sess.created_at + _TTL).isoformat(),
            "meta": sess.meta,
            "has_sample": sess.last_sample is not None,
        }


@router.get("/sessions/{sid}/live")
def live(sid: str) -> dict[str, Any]:
    with _lock:
        sess = _get_fresh(sid)
        return {
            "id": sess.id,
            "code": sess.code,
            "meta": sess.meta,
            "sample": sess.last_sample,
            "notes_n": len(sess.notes),
        }


@router.post("/sessions/{sid}/notes")
async def add_note(sid: str, request: Request) -> dict[str, bool]:
    raw = (await request.body()).decode("utf-8").strip()
    try:
        note = json.loads(raw) if raw else {}
    except json.JSONDecodeError as exc:
        raise HTTPException(400, "JSON invalide") from exc
    if not isinstance(note, dict):
        raise HTTPException(400, "objet JSON attendu")
    with _lock:
        sess = _get_fresh(sid)
        sess.notes.append(note)
    return {"ok": True}


@router.get("/sessions/{sid}/export", response_model=None)
def export_session(sid: str, fmt: str = "json") -> JSONResponse | PlainTextResponse:
    with _lock:
        sess = _get_fresh(sid)
        meta = {
            "id": sess.id,
            "code": sess.code,
            "created_at": sess.created_at.isoformat(),
            "meta": sess.meta,
            "notes": sess.notes,
        }
        lines = [json.dumps(s, ensure_ascii=False) for s in sess.samples]
    if fmt == "jsonl":
        header = json.dumps({"_meta": meta}, ensure_ascii=False)
        body = header + "\n" + "\n".join(lines)
        return PlainTextResponse(body, media_type="application/x-ndjson")
    return JSONResponse({"meta": meta, "jsonl": "\n".join(lines), "samples": sess.samples})
