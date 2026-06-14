#!/bin/bash
# Deploy NID agent to a remote Linux VM via SSH.
# Usage: ./deploy-agent.sh <target_ip> <ssh_user> [agent_id]
#
# Example:
#   ./deploy-agent.sh 192.168.10.20 msfadmin agent-metasploitable
#   ./deploy-agent.sh 192.168.10.30 student agent-ubuntu

set -e

TARGET_IP="${1:?Usage: ./deploy-agent.sh <target_ip> <ssh_user> [agent_id]}"
SSH_USER="${2:?Usage: ./deploy-agent.sh <target_ip> <ssh_user> [agent_id]}"
AGENT_ID="${3:-agent-${TARGET_IP//./-}}"
MANAGER_URL="${NID_MANAGER_URL:-http://192.168.10.50:8080}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/agent"
REMOTE_TMP="/tmp/nid-agent-deploy"

echo "[*] Deploying agent to ${SSH_USER}@${TARGET_IP}"
echo "[*] Agent ID: ${AGENT_ID}"
echo "[*] Manager:  ${MANAGER_URL}"

ssh "${SSH_USER}@${TARGET_IP}" "mkdir -p ${REMOTE_TMP}"
scp -r "${AGENT_DIR}/agent.py" "${AGENT_DIR}/requirements.txt" \
    "${AGENT_DIR}/config.example.env" "${AGENT_DIR}/install-agent.sh" \
    "${SSH_USER}@${TARGET_IP}:${REMOTE_TMP}/"

ssh "${SSH_USER}@${TARGET_IP}" "bash -s" << REMOTE
set -e
cat > /etc/nid-agent.env << EOF
NID_MANAGER_URL=${MANAGER_URL}
NID_AGENT_ID=${AGENT_ID}
NID_HEARTBEAT_INTERVAL=30
EOF
chmod +x ${REMOTE_TMP}/install-agent.sh
sudo ${REMOTE_TMP}/install-agent.sh
REMOTE

echo "[+] Agent deployed to ${TARGET_IP}. Check the manager dashboard for ${AGENT_ID}."
