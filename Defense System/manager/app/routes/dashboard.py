from datetime import datetime, timezone, timedelta

from fastapi import APIRouter

from app.database import get_connection

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("/summary")
def dashboard_summary():
    conn = get_connection()
    agents = conn.execute("SELECT COUNT(*) AS total FROM agents").fetchone()
    online = conn.execute(
        """
        SELECT COUNT(*) AS count FROM agents
        WHERE last_seen >= datetime('now', '-2 minutes')
        """
    ).fetchone()
    alerts_total = conn.execute("SELECT COUNT(*) AS total FROM alerts").fetchone()
    alerts_hour = conn.execute(
        """
        SELECT COUNT(*) AS count FROM alerts
        WHERE timestamp >= datetime('now', '-1 hour')
        """
    ).fetchone()
    recent_alerts = conn.execute(
        "SELECT * FROM alerts ORDER BY timestamp DESC LIMIT 10"
    ).fetchall()
    by_class = conn.execute(
        """
        SELECT attack_class, COUNT(*) AS count
        FROM alerts GROUP BY attack_class ORDER BY count DESC
        """
    ).fetchall()
    capture = conn.execute(
        """
        SELECT * FROM capture_sessions
        WHERE status = 'running' ORDER BY started_at DESC LIMIT 1
        """
    ).fetchone()
    conn.close()

    return {
        "agents_total": agents["total"] if agents else 0,
        "agents_online": online["count"] if online else 0,
        "alerts_total": alerts_total["total"] if alerts_total else 0,
        "alerts_last_hour": alerts_hour["count"] if alerts_hour else 0,
        "capture_active": capture is not None,
        "capture_session": dict(capture) if capture else None,
        "recent_alerts": [dict(row) for row in recent_alerts],
        "alerts_by_class": [dict(row) for row in by_class],
    }


@router.post("/capture/start")
def start_capture(notes: str | None = None):
    now = datetime.now(timezone.utc).isoformat()
    conn = get_connection()
    conn.execute(
        "UPDATE capture_sessions SET status = 'stopped', stopped_at = ? WHERE status = 'running'",
        (now,),
    )
    cur = conn.execute(
        """
        INSERT INTO capture_sessions (started_at, status, notes)
        VALUES (?, 'running', ?)
        """,
        (now, notes or "Lab capture session"),
    )
    conn.commit()
    session_id = cur.lastrowid
    conn.close()
    return {"id": session_id, "started_at": now, "status": "running"}


@router.post("/capture/stop")
def stop_capture():
    now = datetime.now(timezone.utc).isoformat()
    conn = get_connection()
    cur = conn.execute(
        """
        UPDATE capture_sessions SET status = 'stopped', stopped_at = ?
        WHERE status = 'running'
        """,
        (now,),
    )
    conn.commit()
    conn.close()
    return {"status": "stopped" if cur.rowcount else "no_active_session", "stopped_at": now}
