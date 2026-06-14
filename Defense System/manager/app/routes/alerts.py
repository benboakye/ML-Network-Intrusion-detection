from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query

from app.database import get_connection
from app.models import ATTACK_CLASSES, AlertCreate

router = APIRouter(prefix="/api/alerts", tags=["alerts"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("")
def list_alerts(limit: int = Query(default=50, le=200)):
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM alerts ORDER BY timestamp DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


@router.get("/stats")
def alert_stats():
    conn = get_connection()
    by_class = conn.execute(
        """
        SELECT attack_class, COUNT(*) AS count
        FROM alerts
        GROUP BY attack_class
        ORDER BY count DESC
        """
    ).fetchall()
    total = conn.execute("SELECT COUNT(*) AS total FROM alerts").fetchone()
    last_hour = conn.execute(
        """
        SELECT COUNT(*) AS count FROM alerts
        WHERE timestamp >= datetime('now', '-1 hour')
        """
    ).fetchone()
    conn.close()
    return {
        "total": total["total"] if total else 0,
        "last_hour": last_hour["count"] if last_hour else 0,
        "by_class": [dict(row) for row in by_class],
    }


@router.post("")
def create_alert(payload: AlertCreate):
    if payload.attack_class not in ATTACK_CLASSES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid attack_class. Must be one of: {ATTACK_CLASSES}",
        )
    now = _now()
    conn = get_connection()
    cur = conn.execute(
        """
        INSERT INTO alerts (timestamp, attack_class, source_ip, dest_ip, agent_id, severity, confidence, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            now,
            payload.attack_class,
            payload.source_ip,
            payload.dest_ip,
            payload.agent_id,
            payload.severity,
            payload.confidence,
            payload.description,
        ),
    )
    conn.commit()
    alert_id = cur.lastrowid
    conn.close()
    return {"id": alert_id, "timestamp": now, **payload.model_dump()}


@router.post("/seed-demo")
def seed_demo_alerts():
    """Insert sample alerts for UI testing before ML is connected."""
    samples = [
        ("Normal", "192.168.10.10", "192.168.10.20", "low", 0.12, "DNS and HTTP baseline traffic"),
        ("Recon", "192.168.10.10", "192.168.10.20", "medium", 0.91, "Nmap SYN scan detected"),
        ("Brute Force", "192.168.10.10", "192.168.10.20", "high", 0.88, "Repeated SSH login failures"),
        ("Web Attack", "192.168.10.10", "192.168.10.20", "high", 0.85, "SQLi-style HTTP request"),
        ("Exfiltration", "192.168.10.20", "192.168.10.10", "critical", 0.79, "SCP file transfer session"),
    ]
    conn = get_connection()
    for attack_class, src, dst, severity, confidence, desc in samples:
        conn.execute(
            """
            INSERT INTO alerts (timestamp, attack_class, source_ip, dest_ip, severity, confidence, description)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (_now(), attack_class, src, dst, severity, confidence, desc),
        )
    conn.commit()
    conn.close()
    return {"status": "seeded", "count": len(samples)}
