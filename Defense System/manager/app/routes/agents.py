from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException

from app.database import get_connection
from app.models import AgentHeartbeat, AgentRegister

router = APIRouter(prefix="/api/agents", tags=["agents"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("")
def list_agents():
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM agents ORDER BY last_seen DESC"
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


@router.post("/register")
def register_agent(payload: AgentRegister):
    now = _now()
    conn = get_connection()
    conn.execute(
        """
        INSERT INTO agents (agent_id, hostname, ip_address, os_type, status, last_seen, registered_at)
        VALUES (?, ?, ?, ?, 'online', ?, ?)
        ON CONFLICT(agent_id) DO UPDATE SET
            hostname = excluded.hostname,
            ip_address = excluded.ip_address,
            os_type = excluded.os_type,
            status = 'online',
            last_seen = excluded.last_seen
        """,
        (payload.agent_id, payload.hostname, payload.ip_address, payload.os_type, now, now),
    )
    conn.commit()
    conn.close()
    return {"status": "registered", "agent_id": payload.agent_id}


@router.post("/heartbeat")
def agent_heartbeat(payload: AgentHeartbeat):
    now = _now()
    conn = get_connection()
    cur = conn.execute(
        "UPDATE agents SET status = ?, last_seen = ? WHERE agent_id = ?",
        (payload.status, now, payload.agent_id),
    )
    if cur.rowcount == 0:
        conn.close()
        raise HTTPException(status_code=404, detail="Agent not registered")
    conn.commit()
    conn.close()
    return {"status": "ok", "last_seen": now}


@router.delete("/{agent_id}")
def remove_agent(agent_id: str):
    conn = get_connection()
    cur = conn.execute("DELETE FROM agents WHERE agent_id = ?", (agent_id,))
    if cur.rowcount == 0:
        conn.close()
        raise HTTPException(status_code=404, detail="Agent not found")
    conn.commit()
    conn.close()
    return {"status": "removed", "agent_id": agent_id}
