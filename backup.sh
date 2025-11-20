#!/bin/bash
# CCDC BACKUP HUNTER
# Automatically detects running services and backs up their configs + data
# Author: Gemini

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root."
   exit 1
fi

# Create Timestamped Backup Directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/BACKUPS/backup_$TIMESTAMP"
mkdir -p $BACKUP_DIR

echo "==================================================="
echo "      STARTING BACKUP HUNT -> $BACKUP_DIR          "
echo "==================================================="

# --- PHASE 1: CRITICAL SYSTEM FILES ---
echo "[*] Backing up Core System Files..."
# We use --parents to keep the folder structure (e.g., /etc/ssh/...)
cp --parents /etc/passwd $BACKUP_DIR
cp --parents /etc/shadow $BACKUP_DIR
cp --parents /etc/group $BACKUP_DIR
cp --parents /etc/sudoers $BACKUP_DIR
cp --parents /etc/hosts $BACKUP_DIR
cp --parents /etc/fstab $BACKUP_DIR
cp --parents /etc/ssh/sshd_config $BACKUP_DIR
# Backup Cron jobs
if [ -d "/var/spool/cron" ]; then
    cp -r --parents /var/spool/cron $BACKUP_DIR
fi

# --- PHASE 2: WEB SERVER DETECTION ---
echo "[*] Hunting for Web Servers..."

# APACHE
if pgrep -x "apache2" > /dev/null || pgrep -x "httpd" > /dev/null; then
    echo "   [FOUND] Apache Web Server"
    # Backup Configs
    cp -r --parents /etc/apache2 $BACKUP_DIR 2>/dev/null
    cp -r --parents /etc/httpd $BACKUP_DIR 2>/dev/null
    
    # Attempt to find the DocumentRoot (Where the website files live)
    DOC_ROOT=$(grep -r "DocumentRoot" /etc/apache2 /etc/httpd 2>/dev/null | awk '{print $3}' | head -n 1 | tr -d '"')
    if [ ! -z "$DOC_ROOT" ] && [ -d "$DOC_ROOT" ]; then
        echo "   [FOUND] Web Root at: $DOC_ROOT"
        cp -r --parents "$DOC_ROOT" $BACKUP_DIR
    else
        # Fallback
        echo "   [INFO] Could not auto-detect Web Root. Backing up /var/www..."
        cp -r --parents /var/www $BACKUP_DIR 2>/dev/null
    fi
fi

# NGINX
if pgrep -x "nginx" > /dev/null; then
    echo "   [FOUND] Nginx Web Server"
    cp -r --parents /etc/nginx $BACKUP_DIR
    
    # Attempt to find 'root' directive
    WEB_ROOT=$(grep -r "root" /etc/nginx 2>/dev/null | grep -v "#" | awk '{print $2}' | head -n 1 | tr -d ';')
    if [ ! -z "$WEB_ROOT" ] && [ -d "$WEB_ROOT" ]; then
        echo "   [FOUND] Web Root at: $WEB_ROOT"
        cp -r --parents "$WEB_ROOT" $BACKUP_DIR
    else
         cp -r --parents /usr/share/nginx/html $BACKUP_DIR 2>/dev/null
    fi
fi

# --- PHASE 3: DATABASE DETECTION ---
echo "[*] Hunting for Databases..."

if pgrep -x "mysqld" > /dev/null || pgrep -x "mariadbd" > /dev/null; then
    echo "   [FOUND] MySQL/MariaDB"
    echo "   [ACTION] Attempting database dump (may require password)..."
    
    # Try dumping without password (often works for root on localhost)
    mysqldump --all-databases > "$BACKUP_DIR/full_database_dump.sql" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "      [SUCCESS] Database dumped to full_database_dump.sql"
    else
        echo "      [FAIL] Dump failed (Password needed?)."
        echo "      [TIP] Run manually: mysqldump -u root -p --all-databases > backup.sql"
    fi
    
    # Backup Config
    cp --parents /etc/mysql/my.cnf $BACKUP_DIR 2>/dev/null
fi

if pgrep -x "postgres" > /dev/null; then
    echo "   [FOUND] PostgreSQL"
    cp -r --parents /etc/postgresql $BACKUP_DIR 2>/dev/null
    echo "      [TIP] Run manual dump: sudo -u postgres pg_dumpall > pg_backup.sql"
fi

# --- PHASE 4: NETWORK STATE ---
echo "[*] Saving Network State..."
ss -tulpn > "$BACKUP_DIR/initial_open_ports.txt"
ip a > "$BACKUP_DIR/initial_ip_config.txt"

echo "==================================================="
echo "   BACKUP COMPLETE"
echo "   Location: $BACKUP_DIR"
echo "==================================================="