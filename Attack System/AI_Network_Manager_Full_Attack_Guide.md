# AI Network Manager Project

## Full Attack Simulation Guide

*Attack-End Only: Kali-Based Lab Traffic Generation*

**Environment:** Isolated VCloud lab

**Attacker:** Kali Linux

**Targets:** Metasploitable, Ubuntu, Windows

**Purpose:** Generate labeled traffic for future ML-based network detection

**Author:** Bernard Appiah

**Important: This guide is designed for an authorized, isolated school lab only. Do not run these steps against public systems, school production systems, or any network you do not own or have explicit permission to test.**

# Table of Contents

1. Purpose and Scope

2. Lab Architecture

3. Ethical and Safety Boundaries

4. Kali Tool Installation

5. Project Folder Structure

6. Target Preparation Checklist

7. Attack Classes and ML Labels

8. Full Attack Demo Script

9. How to Run the Demonstration

10. Explanation of Each Attack Class

11. Dataset Labeling Plan

12. Troubleshooting

13. One-Week Priority Plan

14. References Consulted

# 1. Purpose and Scope

This document defines the attack-end of the AI Network Manager project. The goal is to generate repeatable, labeled network traffic from Kali Linux so that a future ML-based network manager can be trained and tested against realistic lab activity. The defensive ML side is intentionally not covered in detail here; it will be handled after the attack data-generation process is stable.

The guide focuses on safe simulation rather than destructive exploitation. The attack traffic is designed to be visible to packet capture tools, Zeek, Wireshark, tcpdump, CICFlowMeter, or similar feature extraction tools. Each attack class is separated so that the future ML dataset can be labeled cleanly.

# 2. Lab Architecture

The recommended lab architecture uses Kali Linux as the attack machine and several controlled systems as targets. The AI Manager will later observe traffic and classify it using ML. For now, the AI Manager can simply capture packets and logs.

| System | Role | Example IP Address | Purpose |
| --- | --- | --- | --- |
| Kali Linux | Attacker | e.g. 192.168.10.10 | Runs `attack-demo.sh` and generates labeled traffic. |
| Lab target VM | Vulnerable or service host | discovered at runtime | Receives scans, SSH, web payloads, SCP, and SMB traffic after you select it. |
| AI Manager | Observer / ML platform | e.g. 192.168.10.50 | Captures traffic and later runs detection or ML classification. |

**Note:** IP addresses in this guide are examples only. `attack-demo.sh` auto-detects your lab subnet, discovers live hosts, and asks you to choose **one** target before sending any attack traffic.

# 3. Ethical and Safety Boundaries

- Run the script only inside an isolated VCloud lab that you are authorized to test.
- Use private RFC1918 addresses such as 10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16.
- Do not aim the script at public IP addresses, school production networks, or cloud systems that are not part of the lab.
- Keep brute-force wordlists small because the purpose is traffic labeling, not account compromise.
- Keep DoS-like testing controlled and low-volume because the purpose is to generate recognizable traffic, not crash systems.
- Use harmless sample files for exfiltration simulation. Do not move real secrets, credentials, private files, or personal data.

# 4. Kali Tool Installation

Install the required tools on Kali Linux. These tools are used to generate traffic categories such as DNS, HTTP, SSH, Nmap reconnaissance, Hydra authentication attempts, SMB enumeration, SCP transfer, and controlled SYN burst traffic.

```bash
sudo apt update
sudo apt install -y iproute2 nmap hydra curl dnsutils openssh-client smbclient sshpass hping3 netcat-traditional
```

Optional packet-capture tools on Kali:

```bash
sudo apt install -y wireshark tcpdump
```

# 5. Project Folder Structure

Create a clean project directory on Kali. The folders keep logs, payloads, sample files, and wordlists organized for GitHub documentation and professor demonstration.

```bash
mkdir -p ~/ai-network-manager-attacks
cd ~/ai-network-manager-attacks
mkdir -p logs wordlists payloads exfil
```

The script will automatically create a small demo password list and a harmless sample file if they do not already exist. This keeps the demonstration repeatable.

# 6. Target Preparation Checklist

Before running the attack script, power on your lab VMs and verify the subnet is reachable from Kali. You do **not** need to hardcode target IPs in the script â€” discovery handles that at runtime.

| Step | Preparation | Verification from Kali |
| --- | --- | --- |
| Lab targets | Power on Metasploitable, Ubuntu, or other victim VMs. | `./attack-demo.sh` (discovery lists live hosts) |
| Services | Ensure SSH (port 22), HTTP (port 80), or SMB (port 445) exist on the host you plan to select. | `nmap -sV TARGET_IP` after choosing a target |
| AI Manager | Start packet capture or the defense dashboard before launching attacks. | `curl http://MANAGER_IP:8080/api/health` |
| Credentials | Have SSH username/password ready for exfiltration and lateral movement steps. | `SSH_USER=... SSH_PASS=... ./attack-demo.sh --target TARGET_IP` |

# 7. Attack Classes and ML Labels

The attack-end script generates traffic for these ML labels. Run each class separately when creating a clean training dataset, or run the full demo when presenting the whole workflow.

| Class | Attack Type | Tool or Protocol | Expected Network Behavior |
| --- | --- | --- | --- |
| Normal | Browsing, SSH, DNS | curl, ssh, dig, nslookup | Baseline traffic, ordinary request frequency, common protocols. |
| Recon | Nmap scan, ping sweep | nmap -sn, -sS, -sV | Host discovery, port probing, service enumeration. |
| Brute Force | Hydra SSH attempts | hydra | Repeated authentication attempts and login failures. |
| Web Attack | SQLi and XSS-style requests | curl | HTTP requests containing suspicious parameters and payload patterns. |
| Exfiltration | SCP file transfer | scp, ssh | File transfer traffic with larger or distinct session behavior. |
| Lateral Movement | SMB enumeration and SSH movement | smbclient, ssh | Internal service discovery and remote login activity. |
| DoS | Controlled SYN burst | hping3 | Short burst of SYN packets to a lab web service. |


# 8. Full Attack Demo Script

The script lives in this repository at `Attack System/attack-demo.sh`. It uses **dynamic target discovery** instead of hardcoded IPs.

## Key features

| Feature | Function | Description |
| --- | --- | --- |
| Subnet detection | `detect_lab_subnet()` | Uses `ip route` and `ip -br addr` to find the active interface and CIDR |
| Host discovery | `discover_live_hosts()` | Read-only `nmap -sn` sweep; ping fallback if needed |
| Target selection | `select_target()` | Numbered menu — user must pick and confirm one host |
| Validation | `validate_target_ip()` | Rejects public IPs and the local Kali address |
| Override | `--target` / `TARGET_IP` | Skip discovery and attack a specific lab IP |

All attack modules use a single `TARGET_IP` variable. SSH steps accept `SSH_USER` / `SSH_PASS` or an interactive prompt.

## Run modes

**Interactive discovery (default):**

```bash
cd Attack\ System
chmod +x attack-demo.sh
./attack-demo.sh
```

**Manual target override:**

```bash
./attack-demo.sh --target 192.168.10.30
TARGET_IP=192.168.10.30 ./attack-demo.sh
SSH_USER=student SSH_PASS=student ./attack-demo.sh --target 192.168.10.30
```

See `Attack System/README.md` for the full option reference.

# 9. How to Run the Demonstration

From the `Attack System` directory on Kali:

```bash
chmod +x attack-demo.sh
./attack-demo.sh
```

**Startup flow:**

1. Tool check runs (`nmap`, `hydra`, `ip`, etc.).
2. Lab subnet is auto-detected from your active interface.
3. Live hosts are discovered with `nmap -sn` (no attack traffic yet).
4. You select a target from the list and confirm it.
5. SSH credentials are prompted (or pass `SSH_USER` / `SSH_PASS`).
6. The attack menu opens — all traffic goes to the selected `TARGET_IP`.

**Manual override** (skip discovery menu):

```bash
./attack-demo.sh --target 192.168.10.30
```

Recommended professor demonstration flow:

1. Start packet capture on the AI Manager using tcpdump, Wireshark, Zeek, or another capture method.

2. Run `./attack-demo.sh`, select your lab target, and confirm.

3. Run option 1: Generate Normal Traffic.

4. Wait for the class to complete and observe the label log entry in `logs/attack-labels.csv`.

5. Run option 2: Reconnaissance.

6. Run option 3: Brute Force.

7. Run option 4: Web Attack.

8. Run option 5: Exfiltration (requires SSH credentials).

9. Run option 6: Lateral Movement if time allows.

10. Run option 7: Controlled DoS only if the lab is stable and isolated.

11. Stop packet capture and save the PCAP/log files for the ML side of the project.

# 10. Explanation of Each Attack Class

## 10.1 Normal Traffic

Normal traffic gives the ML system a baseline. Without normal traffic, the model may learn that every event is malicious. The script generates DNS lookups, web requests, and a legitimate SSH login. This class should be captured before attacks so the dataset contains benign examples.

## 10.2 Reconnaissance

Reconnaissance simulates host discovery and service enumeration. The script uses Nmap for ping sweep, SYN scan, and service version detection. This class should create patterns such as many destination ports, repeated probes, and host discovery traffic.

## 10.3 Brute Force

The brute-force class uses Hydra against SSH with a small wordlist. The goal is to create repeated login attempts that your future model can associate with credential attacks. The script uses a deliberately small password list because the objective is labeling and detection, not attacking real systems.

## 10.4 Web Attack

The web attack class sends SQL injection-style and XSS-style requests against a vulnerable web path such as DVWA on Metasploitable. If DVWA requires login cookies in your setup, you can still use the script to generate suspicious HTTP requests, or you can manually browse DVWA/Juice Shop while packet capture is running.

## 10.5 Exfiltration

The exfiltration class uses SCP to create file-transfer traffic. The script performs both upload-style and pull-style transfers with harmless sample files. The pull-style action better represents exfiltration direction because the attacker machine retrieves a file from the target. No real sensitive data should be used.

## 10.6 Lateral Movement

The lateral movement class simulates internal movement behavior using SMB enumeration and SSH access. This is a simplified representation suitable for a one-week project. A more advanced future version could include Active Directory, Windows event logs, and MITRE ATT&CK Atomic Red Team tests.

## 10.7 Controlled DoS-like Traffic

The DoS class uses hping3 to generate a small SYN burst. This should remain low-volume and lab-only. The objective is not to crash Metasploitable or overload VCloud; it is to create a recognizable short burst of SYN traffic for ML labeling.

# 11. Dataset Labeling Plan

The script writes a CSV label log to ./logs/attack-labels.csv. This log can help you align packet-capture time windows with the traffic class that was running. For the ML stage, each time range can be mapped to a class label.

| Script Option | ML Label | Main Evidence in Traffic |
| --- | --- | --- |
| 1. Generate Normal Traffic | Normal | DNS lookups, HTTP HEAD/GET requests, one normal SSH login. |
| 2. Reconnaissance | Recon | Ping sweep, SYN scan, version enumeration. |
| 3. Brute Force | Brute Force | Repeated SSH authentication attempts. |
| 4. Web Attack | Web Attack | HTTP requests with SQLi/XSS-style parameters. |
| 5. Exfiltration | Exfiltration | SCP file transfer sessions. |
| 6. Lateral Movement | Lateral Movement | SMB enumeration and internal SSH activity. |
| 7. Controlled DoS-like SYN Burst | DoS | Short burst of SYN packets to port 80. |

Suggested capture naming convention:

```bash
normal_traffic.pcap
recon_nmap.pcap
bruteforce_hydra_ssh.pcap
web_sqli_xss.pcap
exfil_scp.pcap
lateral_smb_ssh.pcap
dos_syn_burst.pcap
```

# 12. Troubleshooting

| Problem | Likely Cause | Fix |
| --- | --- | --- |
| Hydra fails immediately | SSH not reachable or wrong credentials/username variable. | Run nmap -sV TARGET_IP and verify port 22 is open. |
| DVWA curl requests do not show expected page | DVWA may require login cookies or security level configuration. | Use the requests for traffic generation or manually browse DVWA/Juice Shop during capture. |
| smbclient returns connection errors | Windows SMB may be disabled or firewall blocks SMB. | Enable SMB sharing only inside the lab or treat this class as optional. |
| hping3 does not run | Root privileges required or tool missing. | Run sudo apt install hping3 and execute script with sudo when selecting DoS. |
| No hosts discovered | VMs off or wrong subnet | Power on targets; try `LAB_SUBNET=192.168.10.0/24 ./attack-demo.sh` |
| Script exits at target selection | Invalid or public IP entered | Use a private lab IP; run with `--target` after verifying with `ping` |

# 13. One-Week Priority Plan

Because the deadline is one week, prioritize a clean and demonstrable result over too many attack categories. The strongest minimum viable attack-end is:

1. Normal traffic baseline.

2. Reconnaissance with Nmap.

3. Brute force with Hydra against SSH.

4. Web attack requests against DVWA/Juice Shop or Metasploitable web paths.

5. SCP file transfer for exfiltration simulation.

Add lateral movement and controlled DoS only after the first five classes work reliably and are captured cleanly.

# 14. References Consulted

These references were consulted to keep the guide aligned with current tool purposes and documentation. They are included for your GitHub README and professor review.

- **Nmap Reference Guide:** https://nmap.org/book/man.html
- **THC Hydra GitHub Repository:** https://github.com/vanhauser-thc/thc-hydra
- **OWASP Juice Shop Project:** https://owasp.org/www-project-juice-shop/
- **Zeek Network Security Monitor:** https://zeek.org/
- **CICFlowMeter - Canadian Institute for Cybersecurity:** https://www.unb.ca/cic/research/applications.html
- **Wireshark User Guide:** https://www.wireshark.org/docs/wsug_html_chunked/
- **tcpdump capture guidance in Wireshark User Guide:** https://www.wireshark.org/docs/wsug_html_chunked/AppToolstcpdump.html
