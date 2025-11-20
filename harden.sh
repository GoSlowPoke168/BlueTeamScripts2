#!/bin/bash
# CCDC LITE HARDENING SCRIPT
# Removed: Mass Password Changes, Firewall Rules
# Author: Gemini (Review before running!)

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root."
   exit 1
fi

# LOG FILE
LOGFILE="/var/log/ccdc_hardening.log"
exec > >(tee -a $LOGFILE) 2>&1

echo "==================================================="
echo "      CCDC LINUX PREP (NO FW/PASS CHANGE)          "
echo "==================================================="
echo "Starting at $(date)"

# --- 1. USER INTERACTION ---
echo ""
echo "Enter the password for the NEW 'blueteam' admin user:"
read -s BLUE_PASS

echo ""
echo "Starting setup in 5 seconds..."
sleep 5

# --- 2. INFORMATION GATHERING (FOR INJECTS) ---
echo "[*] Gathering System Info for Injects..."
INFODIR="/root/SYSTEM_INFO"
mkdir -p $INFODIR
hostnamectl > $INFODIR/os_info.txt
ip a > $INFODIR/ip_info.txt
ss -tulpn > $INFODIR/listening_ports.txt
cat /etc/passwd > $INFODIR/initial_users.txt
echo "Info saved to $INFODIR"

# --- 3. BACKUPS ---
echo "[*] Creating Emergency Backups..."
BACKUPDIR="/root/CCDC_BACKUPS"
mkdir -p $BACKUPDIR
cp /etc/ssh/sshd_config $BACKUPDIR/sshd_config.bak
cp /etc/shadow $BACKUPDIR/shadow.bak
cp /etc/passwd $BACKUPDIR/passwd.bak
cp /etc/group $BACKUPDIR/group.bak
# Backup Web/DB configs if they exist
[ -d /etc/apache2 ] && cp -r /etc/apache2 $BACKUPDIR/apache2
[ -d /etc/nginx ] && cp -r /etc/nginx $BACKUPDIR/nginx
[ -d /etc/mysql ] && cp -r /etc/mysql $BACKUPDIR/mysql
echo "Backups saved to $BACKUPDIR"

# --- 4. INSTALL TOOLS ---
echo "[*] Installing Critical Tools..."
apt-get update -y
apt-get install -y auditd htop net-tools vim git curl wget tmux

# --- 5. CREATE BLUE TEAM USER ---
echo "[*] Creating 'blueteam' user..."
if id "blueteam" &>/dev/null; then
    echo "User 'blueteam' already exists."
else
    useradd -m -s /bin/bash blueteam
    echo "blueteam:$BLUE_PASS" | chpasswd
    usermod -aG sudo blueteam
    echo "Blue Team user created."
fi

# --- 6. PERMISSIONS LOCKDOWN ---
echo "[*] Locking down critical files..."
chmod 640 /etc/shadow
chmod 644 /etc/passwd
chown root:root /etc/shadow /etc/passwd
# Prevent non-root users from viewing home dirs of others
chmod 750 /home/*

# --- 7. ENABLE LOGGING (AUDITD) ---
echo "[*] Configuring Auditd Rules..."
cat <<EOF > /etc/audit/rules.d/ccdc.rules
-D
-b 8192
-f 1
-w /etc/passwd -p wa -k identity_theft
-w /etc/shadow -p wa -k identity_theft
-w /bin/nc -p x -k suspicious_tool
-w /bin/netcat -p x -k suspicious_tool
-w /usr/bin/ncat -p x -k suspicious_tool
-w /tmp/ -p x -k tmp_execution
EOF
auditctl -R /etc/audit/rules.d/ccdc.rules
systemctl enable auditd
systemctl restart auditd

# --- 8. SSH HARDENING ---
echo "[*] Hardening SSH Config..."
# We still disable root login and empty passwords as this is basic hygiene
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*Protocol.*/Protocol 2/' /etc/ssh/sshd_config

# Validate and Restart
if sshd -t; then
    systemctl restart sshd
    echo "SSH Hardened."
else
    echo "SSH Config Check Failed! Reverting..."
    cp $BACKUPDIR/sshd_config.bak /etc/ssh/sshd_config
fi

echo "==================================================="
echo "   SETUP COMPLETE.                                 "
echo "   1. Injects info is in /root/SYSTEM_INFO         "
echo "   2. Auditd is logging attacks.                   "
echo "   3. REMINDER: You must manually secure passwords "
echo "      and firewall when ready.                     "
echo "==================================================="