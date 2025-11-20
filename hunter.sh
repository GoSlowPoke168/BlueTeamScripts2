#!/bin/bash
# CCDC THREAT HUNTER & AUDIT TOOL
# Generates "Report-Ready" Evidence
# Author: Gemini

# --- SETUP ---
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Must run as root."
   exit 1
fi

# Create a directory for evidence
REPORT_DIR="/root/IR_EVIDENCE"
mkdir -p $REPORT_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/audit_report_$TIMESTAMP.txt"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log findings
log_finding() {
    local type="$1"
    local evidence="$2"
    local description="$3"

    # Print to screen
    echo -e "${RED}[ALERT] $type detected!${NC}"
    echo -e "   Details: $description"

    # Write to Report File in IR Format
    echo "---------------------------------------------------" >> $REPORT_FILE
    echo "INCIDENT TYPE: $type" >> $REPORT_FILE
    echo "TIME: $(date)" >> $REPORT_FILE
    echo "DESCRIPTION: $description" >> $REPORT_FILE
    echo "EVIDENCE/COMMAND: $evidence" >> $REPORT_FILE
    echo "RECOMMENDED ACTION: Kill process, delete file, or block IP." >> $REPORT_FILE
}

echo -e "${YELLOW}=== STARTING HUNT: Output saved to $REPORT_FILE ===${NC}"
echo "Incident Report Log - Generated $(date)" > $REPORT_FILE

# --- MODULE 1: PROCESS HUNTING ---
echo "Scanning for suspicious processes..."

# 1. Check for tools often used by Red Team (nc, ncat, nmap, metasploit)
# We assume standard names. Smart hackers rename them, but this catches lazy ones.
SUSPICIOUS_PROCS=$(ps aux | grep -E "nc |ncat|netcat|nmap|metasploit|msfconsole|meterpreter" | grep -v grep)

if [ ! -z "$SUSPICIOUS_PROCS" ]; then
    log_finding "Malicious Tool Running" "$SUSPICIOUS_PROCS" "Found known hacking tool process running."
fi

# 2. Check for processes running from temporary directories (/tmp, /dev/shm)
# Malware often lives here because any user can write to them.
TMP_EXECS=$(ls -l /proc/*/exe 2>/dev/null | grep -E "/tmp/|/dev/shm/|/var/tmp/")

if [ ! -z "$TMP_EXECS" ]; then
    log_finding "Execution from Temp Dir" "$TMP_EXECS" "Process running from a temporary directory (High likelihood of malware)."
fi

# --- MODULE 2: NETWORK HUNTING ---
echo "Scanning for suspicious connections..."

# 1. Check for "Reverse Shells" (Connections to non-standard ports)
# Looking for established connections that are NOT Web (80/443) or SSH (22)
WEIRD_CONNS=$(ss -antp | grep "ESTAB" | grep -vE ":22 |:80 |:443 ")

if [ ! -z "$WEIRD_CONNS" ]; then
    log_finding "Suspicious Network Connection" "$WEIRD_CONNS" "Established connection on non-standard port."
fi

# --- MODULE 3: PERSISTENCE HUNTING ---
echo "Scanning for persistence mechanisms..."

# 1. Check Crontabs for all users
# Loops through user spool to find scheduled backdoors
for user in $(cut -f1 -d: /etc/passwd); do
    CRON_DATA=$(crontab -u $user -l 2>/dev/null)
    if [ ! -z "$CRON_DATA" ]; then
        # Just logging it for review, not necessarily an alert unless it looks weird
        echo "USER: $user has cron jobs. Check $REPORT_FILE"
        echo "USER: $user CRON: $CRON_DATA" >> $REPORT_FILE
    fi
done

# 2. Check for World-Writable Files (Files anyone can edit)
# Red Team edits these to escalate privileges
echo "Scanning for World-Writable files (Limit 10)..."
WW_FILES=$(find / -xdev -type f -perm -0002 -print 2>/dev/null | grep -v "/proc" | head -n 10)
if [ ! -z "$WW_FILES" ]; then
   echo "Found World-Writable files. Listed in report."
   echo "--- WORLD WRITABLE FILES AUDIT ---" >> $REPORT_FILE
   echo "$WW_FILES" >> $REPORT_FILE
fi

# 3. Check /etc/passwd for UID 0 (Non-root root accounts)
ROUGE_ROOT=$(awk -F: '($3 == 0) {print $1}' /etc/passwd | grep -v "root")
if [ ! -z "$ROUGE_ROOT" ]; then
    log_finding "Rouge Root Account" "$ROUGE_ROOT" "Found a user with UID 0 that is not named 'root'."
fi

# --- MODULE 4: SUID BINARY AUDIT ---
# Files that run as root regardless of who runs them
echo "Scanning for SUID binaries..."
SUID_BINS=$(find / -perm -4000 -type f 2>/dev/null)
echo "--- SUID BINARIES (Check for weird ones like vim, find, bash) ---" >> $REPORT_FILE
echo "$SUID_BINS" >> $REPORT_FILE

echo -e "${GREEN}=== HUNT COMPLETE ===${NC}"
echo "Review the report here: $REPORT_FILE"