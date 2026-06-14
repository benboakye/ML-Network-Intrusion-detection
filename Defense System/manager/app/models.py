from pydantic import BaseModel, Field


ATTACK_CLASSES = [
    "Normal",
    "Recon",
    "Brute Force",
    "Web Attack",
    "Exfiltration",
    "Lateral Movement",
    "DoS",
]


class AgentRegister(BaseModel):
    agent_id: str
    hostname: str
    ip_address: str
    os_type: str = "linux"


class AgentHeartbeat(BaseModel):
    agent_id: str
    status: str = "online"


class AlertCreate(BaseModel):
    attack_class: str
    source_ip: str | None = None
    dest_ip: str | None = None
    agent_id: str | None = None
    severity: str = "medium"
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    description: str | None = None


class CaptureStart(BaseModel):
    notes: str | None = None
