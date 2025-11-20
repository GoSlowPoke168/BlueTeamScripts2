#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Run as root."
   exit 1
fi

echo "=== SSH KEY WIPER ==="
echo "This will remove ALL authorized_keys files for ALL users."
echo "This forces Password Authentication for everyone."
echo "Press ENTER to continue or CTRL+C to cancel."
read

# Find all authorized_keys files
find / -name "authorized_keys" 2>/dev/null | while read keyfile; do
    echo "Wiping: $keyfile"
    # We overwrite it with empty text rather than deleting the file
    # to preserve permissions/ownership structure.
    > "$keyfile"
    # Make it immutable so they can't add it back easily
    chattr +i "$keyfile"
done

echo "All SSH keys wiped and files locked."