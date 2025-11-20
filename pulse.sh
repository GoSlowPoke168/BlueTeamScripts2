#!/bin/bash

# Define your services here
WEB_PORT=80
SSH_PORT=22
# DB_PORT=3306 (Uncomment if needed)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

while true; do
    clear
    echo "=== SERVICE PULSE MONITOR ==="
    echo "Checking localhost at $(date +%T)..."
    echo "-----------------------------"

    # Check Web
    if nc -z -w 2 127.0.0.1 $WEB_PORT; then
        echo -e "HTTP ($WEB_PORT): ${GREEN}[UP]${NC}"
    else
        echo -e "HTTP ($WEB_PORT): ${RED}[DOWN] - RESTART APACHE/NGINX!${NC}"
        # Optional: Auto-restart (Risky if config is broken)
        # systemctl restart apache2
    fi

    # Check SSH
    if nc -z -w 2 127.0.0.1 $SSH_PORT; then
        echo -e "SSH  ($SSH_PORT): ${GREEN}[UP]${NC}"
    else
        echo -e "SSH  ($SSH_PORT): ${RED}[DOWN] - CHECK CONSOLE!${NC}"
    fi

    echo "-----------------------------"
    sleep 5
done