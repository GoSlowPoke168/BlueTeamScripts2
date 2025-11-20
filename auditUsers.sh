#!/bin/bash

echo "=== STARTING USER PASSWORD AUDIT ==="
echo "Scanning for users with valid shells (UID >= 1000 or root)..."
echo "-----------------------------------------------------------"

# We loop through /etc/passwd
# $1 is username, $3 is UID, $7 is shell
while IFS=: read -r username x uid gid comment home shell; do

    # Check if user is root (UID 0) or a normal user (UID >= 1000)
    # AND check if they have a valid shell (bash or sh)
    if [[ ("$uid" -eq 0 || "$uid" -ge 1000) && ("$shell" == *"/bin/bash" || "$shell" == *"/bin/sh") ]]; then
        
        # Exclude the 'nobody' user just in case
        if [ "$username" == "nobody" ]; then
            continue
        fi

        echo "FOUND USER: $username (UID: $uid)"
        echo "Changing password for $username..."
        
        # The passwd command is interactive; it will ask you to type the password twice
        passwd "$username"
        
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] Password changed for $username"
        else
            echo "[ERROR] Failed to change password for $username"
        fi
        echo "-----------------------------------------------------------"
    fi

done < /etc/passwd

echo "=== AUDIT COMPLETE ==="