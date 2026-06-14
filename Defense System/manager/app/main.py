from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.database import init_db
from app.routes import agents, alerts, dashboard

STATIC_DIR = Path(__file__).resolve().parent.parent / "static"

app = FastAPI(
    title="ML Network Intrusion Detection Manager",
    description="Central manager for agents, alerts, and capture sessions",
    version="0.1.0",
)

app.include_router(agents.router)
app.include_router(alerts.router)
app.include_router(dashboard.router)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.on_event("startup")
def on_startup():
    init_db()


@app.get("/")
def root():
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/health")
def health():
    return {"status": "ok", "service": "nid-manager"}
