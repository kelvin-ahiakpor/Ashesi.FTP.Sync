#!/bin/bash

# Constants
FTP_HOST="169.239.251.102"
FTP_PORT=321
CONFIG_FILE="${HOME}/Development/scripts/sync_config.conf"
KEYCHAIN_NAME="ashesi_ftp_sync"
LFTP_SCRIPT="/tmp/lftp_commands_$$"
DEBOUNCE_DELAY=2

# Check for required commands
for cmd in lftp fswatch security; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
done

# Error handling
set -e
trap 'cleanup' EXIT INT TERM

cleanup() {
    echo "Cleaning up..."
    rm -f "$LFTP_SCRIPT"
    exit 0
}

# Directory check
if [ ! -d "${HOME}/Development/scripts" ]; then
    mkdir -p "${HOME}/Development/scripts"
fi

# Config and credential handling
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    CACHED_PASS=$(security find-generic-password -w -a "$FTP_USER" -s "$KEYCHAIN_NAME")
else
    echo "First time setup..."
    read -p "Enter your Ashesi username: " FTP_USER
    read -sp "Enter your FTP password: " FTP_PASS
    echo
    read -p "Enter local path: " LOCAL_DIR
    read -p "Enter remote path: " REMOTE_DIR
    
    security add-generic-password -a "$FTP_USER" -s "$KEYCHAIN_NAME" -w "$FTP_PASS"
    CACHED_PASS="$FTP_PASS"
    
    cat <<EOL > "$CONFIG_FILE"
FTP_USER="$FTP_USER"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
EOL
fi

# Create persistent LFTP script
cat > "$LFTP_SCRIPT" << EOF
set ssl:verify-certificate no
set ftp:ssl-allow no
set net:timeout 10
set net:max-retries 3
set net:reconnect-interval-base 5
open -u "$FTP_USER","$CACHED_PASS" -p $FTP_PORT $FTP_HOST
EOF

# Sync function with persistent connection
sync_files() {
    echo "$(date '+%H:%M:%S') - Syncing changes..."
    lftp -f "$LFTP_SCRIPT" << EOF
mirror -R --verbose --only-newer "$LOCAL_DIR" "$REMOTE_DIR"
EOF
}

# Print configuration
echo "========================="
echo "FTP Host: $FTP_HOST"
echo "Username: $FTP_USER"
echo "Local Directory: $LOCAL_DIR"
echo "Remote Directory: $REMOTE_DIR"
echo "========================="

# Initial sync
sync_files

# Simple timestamp-based debouncing
last_sync_time=0

# Monitor changes
fswatch -o "$LOCAL_DIR" | while read change; do
    current_time=$(date +%s)
    
    if (( current_time - last_sync_time >= DEBOUNCE_DELAY )); then
        echo "$(date '+%H:%M:%S') - Change detected, syncing..."
        sync_files
        last_sync_time=$current_time
    fi
done