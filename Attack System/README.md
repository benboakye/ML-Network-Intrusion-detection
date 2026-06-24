# Attack System

Lab-only attack traffic generator for the ML Network Intrusion Detection project. Run from **Kali Linux** inside your authorized VCloud lab.

## Quick start

```bash
cd "Attack System"
chmod +x attack-demo.sh
./attack-demo.sh
```

The script will:

1. Detect your active network interface and lab subnet
2. Discover live hosts with `nmap -sn` (read-only)
3. Show a numbered list and ask you to **choose one target**
4. Ask you to **confirm** before any attack traffic is sent

## Manual target override

Skip discovery and attack a specific host directly:

```bash
./attack-demo.sh --target 192.168.10.30
```

Or with an environment variable:

```bash
TARGET_IP=192.168.10.30 ./attack-demo.sh
```

With SSH credentials (for exfiltration, normal SSH, lateral movement):

```bash
SSH_USER=student SSH_PASS=student ./attack-demo.sh --target 192.168.10.30
```

## Options

| Flag / variable | Description |
|-----------------|-------------|
| `--target`, `-t` / `TARGET_IP` | Target IP (skips discovery menu) |
| `--subnet`, `-s` / `LAB_SUBNET` | Override auto-detected subnet |
| `--user`, `-u` / `SSH_USER` | SSH username |
| `--pass`, `-p` / `SSH_PASS` | SSH password |
| `--help`, `-h` | Show usage |

## Attack menu

| Option | Class |
|--------|-------|
| 1 | Normal traffic (DNS, HTTP, SSH) |
| 2 | Reconnaissance (nmap sweep + port scan) |
| 3 | Brute force (Hydra SSH) |
| 4 | Web attack (SQLi/XSS-style requests) |
| 5 | Exfiltration (SCP file transfer) |
| 6 | Lateral movement (SMB + SSH) |
| 7 | Controlled DoS-like SYN burst |
| 8 | Run full demo |
| 0 | Change target |
| 9 | Exit |

## Safety

- Only private RFC1918 IPs are accepted as targets
- You cannot target your own machine (Kali)
- Discovery does **not** attack hosts — only `nmap -sn` / ping
- Attack traffic goes **only** to the selected `TARGET_IP`
- SSH/SCP steps are skipped gracefully if credentials are missing

## Outputs

| Path | Contents |
|------|----------|
| `logs/attack-labels.csv` | Timestamped ML class labels |
| `logs/*.log` | Per-step tool output |
| `exfil/` | Pulled sample files from exfil simulation |

## Lab architecture (example IPs)

IPs below are **examples only**. The script discovers targets automatically.

| Role | Example IP |
|------|------------|
| Kali (attacker) | 192.168.10.10 |
| Vulnerable Linux target | 192.168.10.20 |
| Ubuntu server | 192.168.10.30 |
| AI Manager (defense) | 192.168.10.50 |

## Dependencies

```bash
sudo apt update
sudo apt install -y iproute2 nmap hydra curl dnsutils openssh-client smbclient sshpass hping3 netcat-traditional
```

## Related docs

- `AI_Network_Manager_Full_Attack_Guide.md` — full attack guide and demo workflow
- `../Defense System/deploy_guide.md` — manager and agent deployment
