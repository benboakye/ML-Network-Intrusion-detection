# Deployment Guide

## ML Network Intrusion Detection — Defense System

**Author:** Bernard Appiah  
**Environment:** Isolated VCloud lab only  
**Purpose:** Deploy the central manager and lightweight agents across lab VMs

> **Important:** Run these steps only inside your authorized school lab. Do not deploy against production networks or systems you do not own or have permission to test.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Lab Architecture](#2-lab-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Deploy the Manager](#4-deploy-the-manager)
5. [Deploy Agents to Target VMs](#5-deploy-agents-to-target-vms)
6. [Verify Deployment](#6-verify-deployment)
7. [Run a Full Demo](#7-run-a-full-demo)
8. [Optional: Manager as a systemd Service](#8-optional-manager-as-a-systemd-service)
9. [Firewall and Network Notes](#9-firewall-and-network-notes)
10. [Troubleshooting](#10-troubleshooting)
11. [Updating After Code Changes](#11-updating-after-code-changes)

---

## 1. Overview

The Defense System uses a **Wazuh-style layout**:

| Component | Role | Deploy on |
|-----------|------|-----------|
| **Manager** | API, dashboard, alert storage | AI Manager VM |
| **Agent** | Registers with manager, sends heartbeats | Metasploitable, Ubuntu, etc. |
| **Attack System** | Generates labeled traffic (separate repo folder) | Kali Linux |

The manager listens on **port 8080**. Agents connect to the manager over HTTP and appear on the dashboard within about 30 seconds.

---

## 2. Lab Architecture

| System | Role | Example IP | Deploy |
|--------|------|------------|--------|
| Kali Linux | Attacker | 192.168.10.10 | Attack System only |
| Metasploitable | Vulnerable target | 192.168.10.20 | Agent |
| Ubuntu Server | Normal service target | 192.168.10.30 | Agent |
| Windows Machine | SMB / endpoint target | 192.168.10.40 | Optional (Linux agents only for now) |
| AI Manager | Manager + dashboard | 192.168.10.50 | Manager |

```
                    ┌─────────────────────────────┐
                    │   AI Manager (192.168.10.50) │
                    │   FastAPI + Dashboard :8080  │
                    └──────────────┬──────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
     ┌────────▼────────┐  ┌────────▼────────┐  ┌───────▼───────┐
     │ Metasploitable  │  │ Ubuntu Server   │  │ Kali (attacks)│
     │ Agent : —       │  │ Agent : —       │  │ no agent      │
     │ 192.168.10.20   │  │ 192.168.10.30   │  │ 192.168.10.10 │
     └─────────────────┘  └─────────────────┘  └───────────────┘
```

Update IP addresses in this guide and in `deploy-agent.sh` / `/etc/nid-agent.env` if your VCloud subnet differs.

---

## 3. Prerequisites

### Manager VM (192.168.10.50)

- Ubuntu Server 20.04+ or similar Linux
- Python 3.10+
- Git (to clone the repo) or SCP access to copy files
- Port **8080** open on the lab network

### Target VMs (agents)

- Linux with `systemd` (Metasploitable, Ubuntu)
- SSH access from the manager VM or your workstation
- `sudo` privileges on the target
- Outbound HTTP access to the manager on port 8080

### From your workstation or manager

- SSH client and SCP
- Network reachability to all lab VMs

### Clone the repository (manager VM)

```bash
git clone https://github.com/benboakye/ML-Network-Intrusion-detection.git
cd ML-Network-Intrusion-detection/Defense\ System
```

If you copied files manually, ensure the `Defense System/` folder contains `manager/`, `agent/`, and `deploy-agent.sh`.

---

## 4. Deploy the Manager

All commands below run on the **AI Manager VM** (192.168.10.50).

### Step 4.1 — Install Python dependencies

```bash
cd Defense\ System/manager

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Step 4.2 — Start the manager

```bash
python run.py
```

Expected output:

```
INFO:     Uvicorn running on http://0.0.0.0:8080
```

Leave this terminal open, or use [Section 8](#8-optional-manager-as-a-systemd-service) to run it as a background service.

### Step 4.3 — Open the dashboard

From any machine on the lab network, open a browser:

```
http://192.168.10.50:8080
```

You should see the **Network Intrusion Detection** dashboard with empty agent and alert tables.

### Step 4.4 — Confirm API health

```bash
curl http://192.168.10.50:8080/api/health
```

Expected response:

```json
{"status":"ok","service":"nid-manager"}
```

### Step 4.5 — Optional: seed demo alerts

On the dashboard, click **Seed Demo Alerts**, or run:

```bash
curl -X POST http://192.168.10.50:8080/api/alerts/seed-demo
```

This populates sample alerts for UI testing before ML is connected.

---

## 5. Deploy Agents to Target VMs

Agents can be deployed from the manager VM or any host with SSH access to the targets.

### Step 5.1 — Make scripts executable

```bash
cd Defense\ System
chmod +x deploy-agent.sh agent/install-agent.sh
```

### Step 5.2 — Deploy to Metasploitable

Default credentials: `msfadmin` / `msfadmin`

```bash
./deploy-agent.sh 192.168.10.20 msfadmin agent-metasploitable
```

### Step 5.3 — Deploy to Ubuntu Server

Replace `student` with your Ubuntu lab username if different:

```bash
./deploy-agent.sh 192.168.10.30 student agent-ubuntu
```

### Step 5.4 — Custom manager URL

If the manager is not at the default address:

```bash
NID_MANAGER_URL=http://192.168.10.50:8080 ./deploy-agent.sh 192.168.10.20 msfadmin agent-metasploitable
```

### What `deploy-agent.sh` does

1. Copies agent files to `/tmp/nid-agent-deploy/` on the target
2. Writes `/etc/nid-agent.env` with manager URL and agent ID
3. Installs Python venv at `/opt/nid-agent`
4. Creates and starts the `nid-agent` systemd service

### Manual agent install (alternative)

If SSH deploy fails, run these steps **directly on the target VM**:

```bash
# On the target VM
sudo mkdir -p /opt/nid-agent
sudo cp agent.py requirements.txt /opt/nid-agent/

sudo tee /etc/nid-agent.env << EOF
NID_MANAGER_URL=http://192.168.10.50:8080
NID_AGENT_ID=agent-metasploitable
NID_HEARTBEAT_INTERVAL=30
EOF

cd /opt/nid-agent
sudo apt update && sudo apt install -y python3 python3-venv
sudo python3 -m venv venv
sudo ./venv/bin/pip install -r requirements.txt
sudo bash /path/to/install-agent.sh
```

### Agent environment variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NID_MANAGER_URL` | Manager API base URL | `http://192.168.10.50:8080` |
| `NID_AGENT_ID` | Unique agent identifier | `agent-metasploitable` |
| `NID_HEARTBEAT_INTERVAL` | Seconds between heartbeats | `30` |

Edit on the target:

```bash
sudo nano /etc/nid-agent.env
sudo systemctl restart nid-agent
```

---

## 6. Verify Deployment

### 6.1 — Check agents on the dashboard

Open `http://192.168.10.50:8080`. The **Registered Agents** table should list each deployed host with status **online**.

### 6.2 — Check via API

```bash
curl http://192.168.10.50:8080/api/agents
```

Example response:

```json
[
  {
    "agent_id": "agent-metasploitable",
    "hostname": "metasploitable",
    "ip_address": "192.168.10.20",
    "os_type": "linux",
    "status": "online",
    "last_seen": "2026-06-13T18:30:00+00:00"
  }
]
```

### 6.3 — Check agent service on target VM

```bash
ssh msfadmin@192.168.10.20 "sudo systemctl status nid-agent"
```

Healthy output includes `Active: active (running)`.

### 6.4 — View agent logs

```bash
ssh msfadmin@192.168.10.20 "sudo journalctl -u nid-agent -f"
```

Look for:

```
[+] Registered as agent-metasploitable (metasploitable @ 192.168.10.20)
```

---

## 7. Run a Full Demo

Use this sequence for a professor demonstration or end-to-end lab test.

| Step | Where | Action |
|------|-------|--------|
| 1 | Manager VM | Start manager (`python run.py` or systemd) |
| 2 | Manager VM | Deploy agents to Metasploitable and Ubuntu |
| 3 | Browser | Open dashboard, confirm agents are **online** |
| 4 | Dashboard | Click **Start** under Capture |
| 5 | Kali | Run `./attack-demo.sh` from Attack System (one class at a time) |
| 6 | Dashboard | Refresh — view alerts (demo seed now; ML alerts later) |
| 7 | Dashboard | Click **Stop** under Capture when finished |

### Recommended attack order (matches ML labels)

1. Normal Traffic  
2. Reconnaissance  
3. Brute Force  
4. Web Attack  
5. Exfiltration  

Run each class separately with a pause between them so capture and labeling stay clean. The attack script writes timestamps to `logs/attack-labels.csv` on Kali for alignment with manager alerts.

---

## 8. Optional: Manager as a systemd Service

Run the manager in the background on the AI Manager VM.

### Create the service file

```bash
sudo tee /etc/systemd/system/nid-manager.service << 'EOF'
[Unit]
Description=ML Network Intrusion Detection Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=student
WorkingDirectory=/home/student/ML-Network-Intrusion-detection/Defense System/manager
Environment=PATH=/home/student/ML-Network-Intrusion-detection/Defense System/manager/venv/bin
ExecStart=/home/student/ML-Network-Intrusion-detection/Defense System/manager/venv/bin/python run.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Adjust `User`, `WorkingDirectory`, and paths to match your VM.

### Enable and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable nid-manager
sudo systemctl start nid-manager
sudo systemctl status nid-manager
```

### View manager logs

```bash
sudo journalctl -u nid-manager -f
```

---

## 9. Firewall and Network Notes

### Allow manager port (on AI Manager VM)

```bash
sudo ufw allow 8080/tcp
sudo ufw reload
```

If `ufw` is inactive, no action is needed unless your lab enforces external firewall rules.

### Agent connectivity

Agents only need **outbound** access to the manager:

```
Target VM → http://192.168.10.50:8080/api/agents/register
Target VM → http://192.168.10.50:8080/api/agents/heartbeat
```

Test from a target VM:

```bash
curl http://192.168.10.50:8080/api/health
```

### Windows agents

The current agent is Python/Linux only. Windows deployment is not included in v0.1. Use Metasploitable and Ubuntu for the demo, or add a Windows agent in a later phase.

---

## 10. Troubleshooting

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| Dashboard not loading | Manager not running or port blocked | `systemctl status nid-manager` or restart `python run.py`; check `ufw` |
| Agent shows offline | Heartbeat failing or manager unreachable | `curl http://192.168.10.50:8080/api/health` from target; check `/etc/nid-agent.env` |
| `deploy-agent.sh` SSH fails | Wrong user, password, or IP | Verify SSH manually: `ssh msfadmin@192.168.10.20` |
| Agent service crash loop | Wrong manager URL or missing Python deps | `sudo journalctl -u nid-agent -n 50` |
| Duplicate agent entries | Re-deployed with new agent ID | Remove old entry via API or restart with consistent `NID_AGENT_ID` |
| No alerts after attacks | ML not connected yet | Use **Seed Demo Alerts** or wait for ML phase; confirm capture is started |
| `Permission denied` on install | Script not run as root | Use `deploy-agent.sh` (handles sudo) or `sudo ./install-agent.sh` |

### Reset agent on a target VM

```bash
sudo systemctl stop nid-agent
sudo systemctl disable nid-agent
sudo rm -rf /opt/nid-agent
sudo rm /etc/systemd/system/nid-agent.service
sudo systemctl daemon-reload
```

Then re-run `./deploy-agent.sh`.

### Reset manager database

Stop the manager, then delete the SQLite file:

```bash
rm -f Defense\ System/manager/data/nid.db
```

Restart the manager — tables are recreated automatically.

---

## 11. Updating After Code Changes

### Update manager

```bash
cd ML-Network-Intrusion-detection
git pull
cd Defense\ System/manager
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart nid-manager   # or restart python run.py
```

### Update agents

Re-run deploy for each target:

```bash
./deploy-agent.sh 192.168.10.20 msfadmin agent-metasploitable
./deploy-agent.sh 192.168.10.30 student agent-ubuntu
```

Or on the target only:

```bash
sudo systemctl restart nid-agent
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Start manager | `cd manager && source venv/bin/activate && python run.py` |
| Open dashboard | `http://192.168.10.50:8080` |
| Deploy agent | `./deploy-agent.sh <ip> <user> <agent_id>` |
| Check agents | `curl http://192.168.10.50:8080/api/agents` |
| Agent status | `sudo systemctl status nid-agent` |
| Agent logs | `sudo journalctl -u nid-agent -f` |
| Seed demo alerts | Click **Seed Demo Alerts** on dashboard |

---

## Related Documentation

- `Defense System/README.md` — project overview and API reference  
- `Attack System/AI_Network_Manager_Full_Attack_Guide.md` — attack traffic generation  
- GitHub: https://github.com/benboakye/ML-Network-Intrusion-detection
