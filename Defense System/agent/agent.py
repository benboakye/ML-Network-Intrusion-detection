#!/usr/bin/env python3
"""
NID Agent - lightweight host agent for the ML Network Intrusion Detection manager.
Registers with the manager, sends heartbeats, and can forward events.
"""

import os
import socket
import sys
import time
import uuid

try:
    import httpx
except ImportError:
    print("Install dependencies: pip install httpx")
    sys.exit(1)

MANAGER_URL = os.environ.get("NID_MANAGER_URL", "http://192.168.10.50:8080")
AGENT_ID = os.environ.get("NID_AGENT_ID", f"agent-{uuid.uuid4().hex[:8]}")
HEARTBEAT_INTERVAL = int(os.environ.get("NID_HEARTBEAT_INTERVAL", "30"))


def get_hostname() -> str:
    return socket.gethostname()


def get_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


def get_os_type() -> str:
    if sys.platform.startswith("linux"):
        return "linux"
    if sys.platform == "win32":
        return "windows"
    return sys.platform


def register(client: httpx.Client) -> None:
    payload = {
        "agent_id": AGENT_ID,
        "hostname": get_hostname(),
        "ip_address": get_ip(),
        "os_type": get_os_type(),
    }
    resp = client.post(f"{MANAGER_URL}/api/agents/register", json=payload)
    resp.raise_for_status()
    print(f"[+] Registered as {AGENT_ID} ({payload['hostname']} @ {payload['ip_address']})")


def heartbeat(client: httpx.Client) -> None:
    resp = client.post(
        f"{MANAGER_URL}/api/agents/heartbeat",
        json={"agent_id": AGENT_ID, "status": "online"},
    )
    resp.raise_for_status()


def send_event(client: httpx.Client, attack_class: str, description: str, **kwargs) -> None:
    payload = {
        "attack_class": attack_class,
        "agent_id": AGENT_ID,
        "source_ip": kwargs.get("source_ip"),
        "dest_ip": kwargs.get("dest_ip"),
        "severity": kwargs.get("severity", "medium"),
        "confidence": kwargs.get("confidence", 0.5),
        "description": description,
    }
    resp = client.post(f"{MANAGER_URL}/api/alerts", json=payload)
    resp.raise_for_status()
    print(f"[+] Event sent: {attack_class} - {description}")


def main() -> None:
    print(f"[*] NID Agent starting")
    print(f"[*] Manager: {MANAGER_URL}")
    print(f"[*] Agent ID: {AGENT_ID}")

    with httpx.Client(timeout=10.0) as client:
        while True:
            try:
                register(client)
                break
            except httpx.HTTPError as e:
                print(f"[!] Registration failed: {e}. Retrying in 10s...")
                time.sleep(10)

        while True:
            try:
                heartbeat(client)
            except httpx.HTTPError as e:
                print(f"[!] Heartbeat failed: {e}")
            time.sleep(HEARTBEAT_INTERVAL)


if __name__ == "__main__":
    main()
