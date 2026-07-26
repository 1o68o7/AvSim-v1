"""Persistance SQLite EventStore — survie au redémarrage de process."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path

from avsim.io.events import EventStore, StrokeMark


_WRITE_SCRIPT = textwrap.dedent(
    """\
    import json, sys
    from avsim.io.events import EventStore, StrokeMark

    db = sys.argv[1]
    store = EventStore(db)
    sess = store.create_session("2x")
    store.add_stroke_mark(
        sess.session_id,
        StrokeMark(
            stroke_index=0,
            t_utc="2026-07-26T12:00:00+00:00",
            cadence_spm=36.0,
            v_ms=4.0,
            check_factor=0.5,
            arc_deg=100.0,
            phase_lag_ms=0.0,
            energy={"P_rower_mean_W": 210.0},
        ),
    )
    ev = store.add_event(
        sess.session_id,
        source="coach_voice",
        tag="longueur",
        transcript="survit au restart",
        t_utc="2026-07-26T12:00:02+00:00",
    )
    print(json.dumps({
        "session_id": sess.session_id,
        "event_id": ev.event_id,
        "db": str(store.path),
    }))
    """
)

_READ_SCRIPT = textwrap.dedent(
    """\
    import json, sys
    from avsim.io.events import EventStore

    db, session_id, event_id = sys.argv[1], sys.argv[2], sys.argv[3]
    store = EventStore(db)
    sess = store.get(session_id)
    assert sess is not None, "session absente après restart"
    assert sess.boat_class == "2x"
    assert len(sess.strokes) == 1
    assert sess.strokes[0].cadence_spm == 36.0
    assert sess.strokes[0].energy["P_rower_mean_W"] == 210.0
    assert len(sess.events) == 1
    assert sess.events[0].event_id == event_id
    assert sess.events[0].transcript == "survit au restart"
    nearest = store.nearest_stroke_index(session_id, "2026-07-26T12:00:02+00:00")
    assert nearest == 0
    print("ok")
    """
)


def _sub_env() -> dict[str, str]:
    env = os.environ.copy()
    env["PYTHONPATH"] = "src"
    return env


def test_event_store_survives_process_restart(tmp_path: Path) -> None:
    """Écriture process A → lecture process B (même fichier SQLite)."""
    db = tmp_path / "events_restart.sqlite"
    write = subprocess.run(
        [sys.executable, "-c", _WRITE_SCRIPT, str(db)],
        check=True,
        capture_output=True,
        text=True,
        cwd="/workspace",
        env=_sub_env(),
    )
    meta = json.loads(write.stdout.strip().splitlines()[-1])
    assert Path(meta["db"]).resolve() == db.resolve()
    assert db.is_file() and db.stat().st_size > 0

    read = subprocess.run(
        [
            sys.executable, "-c", _READ_SCRIPT,
            str(db), meta["session_id"], meta["event_id"],
        ],
        check=True,
        capture_output=True,
        text=True,
        cwd="/workspace",
        env=_sub_env(),
    )
    assert "ok" in read.stdout


def test_event_store_reopen_reloads_from_disk(tmp_path: Path) -> None:
    """Même process : nouvel EventStore(path) relit le fichier."""
    db = tmp_path / "events_reopen.sqlite"
    a = EventStore(db)
    sess = a.create_session("2x")
    a.add_event(sess.session_id, source="coach_voice", tag="t")
    a.add_stroke_mark(
        sess.session_id,
        StrokeMark(
            stroke_index=1,
            t_utc="2026-07-26T13:00:00+00:00",
            cadence_spm=32.0,
            v_ms=3.5,
            check_factor=0.4,
        ),
    )
    sid = sess.session_id

    b = EventStore(db)
    loaded = b.get(sid)
    assert loaded is not None
    assert len(loaded.strokes) == 1
    assert len(loaded.events) == 1
    assert loaded.events[0].tag == "t"

    from avsim.io.events import STORE

    STORE.reopen(db)
    assert STORE.get(sid) is not None
    assert STORE.path.resolve() == db.resolve()
