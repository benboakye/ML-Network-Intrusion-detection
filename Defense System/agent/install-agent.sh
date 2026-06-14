#!/bin/bash
# Install NID agent as a systemd service on a Linux VM.
# Run on the TARGET machine (or via deploy-agent.sh from the manager).

set -e

INSTALL_DIR="/opt/nid-agent"
SERVICE_NAME="nid-agent"
ENV_FILE="/etc/nid-agent.env"

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./install-agent.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/agent.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"

if [ ! -f "$ENV_FILE" ]; then
    cp "$SCRIPT_DIR/config.example.env" "$ENV_FILE"
    echo "[*] Created $ENV_FILE — edit NID_MANAGER_URL and NID_AGENT_ID before starting."
fi

apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv

python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install -q -r "$INSTALL_DIR/requirements.txt"

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=NID Network Intrusion Detection Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=$ENV_FILE
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "[+] Agent installed and started."
echo "[+] Status: systemctl status $SERVICE_NAME"
systemctl status "$SERVICE_NAME" --no-pager || true
