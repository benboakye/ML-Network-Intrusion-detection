# Defense System - ML Network Intrusion Detection Manager

Central manager + lightweight agents for the isolated VCloud lab. Wazuh-inspired layout: one manager VM with a dashboard, agents on target VMs.

## Architecture

```
Manager VM (192.168.10.50)          Target VMs
┌─────────────────────────┐         ┌──────────────────┐
│  FastAPI + Dashboard    │◄────────│  NID Agent       │
│  SQLite                 │ heartbeat│  (Metasploitable)│
│  Port 8080              │         └──────────────────┘
└─────────────────────────┘         ┌──────────────────┐
         ▲                          │  NID Agent       │
         │                          │  (Ubuntu)        │
    Kali attack traffic             └──────────────────┘
    (separate Attack System)
```

## Quick start (Manager VM)

```bash
cd manager
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

Open **http://192.168.10.50:8080** in a browser.

Click **Seed Demo Alerts** to populate the dashboard before ML is connected.

## Deploy an agent to a lab VM

From the manager or any machine with SSH access to targets:

```bash
chmod +x deploy-agent.sh agent/install-agent.sh
./deploy-agent.sh 192.168.10.20 msfadmin agent-metasploitable
./deploy-agent.sh 192.168.10.30 student agent-ubuntu
```

Set the manager URL if needed:

```bash
NID_MANAGER_URL=http://192.168.10.50:8080 ./deploy-agent.sh 192.168.10.20 msfadmin
```

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/dashboard/summary` | Dashboard stats |
| GET | `/api/agents` | List registered agents |
| POST | `/api/agents/register` | Agent registration |
| POST | `/api/agents/heartbeat` | Agent heartbeat |
| GET | `/api/alerts` | List alerts |
| POST | `/api/alerts` | Create alert |
| POST | `/api/alerts/seed-demo` | Insert sample alerts |
| POST | `/api/dashboard/capture/start` | Start capture session |
| POST | `/api/dashboard/capture/stop` | Stop capture session |

## Attack classes (aligned with Attack System)

Normal, Recon, Brute Force, Web Attack, Exfiltration, Lateral Movement, DoS

## Demo workflow

1. Start the manager on the AI Manager VM.
2. Deploy agents to Metasploitable and Ubuntu.
3. Click **Start** capture on the dashboard.
4. Run attack classes from Kali (`Attack System/attack-demo.sh`).
5. View alerts on the dashboard (demo seed now; ML inference later).

## Next steps (ML phase)

- [ ] PCAP/flow capture on manager (tcpdump or Zeek)
- [ ] Feature extraction (CICFlowMeter)
- [ ] Train classifier on labeled attack traffic
- [ ] Replace demo alerts with real ML inference in `/api/alerts`

## Project structure

```
Defense System/
├── manager/           # FastAPI backend + dashboard
│   ├── app/
│   ├── static/
│   └── run.py
├── agent/             # Lightweight VM agent
│   ├── agent.py
│   └── install-agent.sh
└── deploy-agent.sh    # Remote agent deployment
```
