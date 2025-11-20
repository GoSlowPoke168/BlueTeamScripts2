#!/bin/bash
# Usage: sudo ./ban.sh [IP_ADDRESS]

if [ -z "$1" ]; then
    echo "Usage: ./ban.sh <IP_ADDRESS>"
    exit 1
fi

TARGET_IP=$1

echo "!!! BANNING IP: $TARGET_IP !!!"

# 1. Add to UFW (Firewall) at Position 1 (Top Priority)
ufw insert 1 deny from $TARGET_IP to any
echo "[+] Firewall rule added."

# 2. Kill existing connections immediately (TCPKILL)
# Note: Requires 'dsniff' package, or use 'ss' method below
if command -v tcpkill &> /dev/null; then
    timeout 5s tcpkill -9 host $TARGET_IP &>/dev/null &
    echo "[+] tcpkill launched for 5 seconds."
fi

# 3. Manual Kill via SS (If tcpkill isn't installed)
# Finds specific PIDs talking to that IP and kills them
PIDS=$(ss -Kp | grep $TARGET_IP | awk '{print $2}' | grep -o '[0-9]*' | sort -u)
if [ ! -z "$PIDS" ]; then
    echo "Killing PIDs connected to $TARGET_IP: $PIDS"
    kill -9 $PIDS
fi

echo "Target $TARGET_IP has been neutralized."