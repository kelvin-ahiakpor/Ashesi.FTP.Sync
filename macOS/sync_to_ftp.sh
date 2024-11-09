#!/bin/bash

# Ashesi Server Constants
FTP_HOST="169.239.251.102"
FTP_PORT=321

# Path to the configuration file within Development/scripts
CONFIG_FILE="${HOME}/Development/scripts/sync_config.conf"
KEYCHAIN_NAME="ashesi_ftp_sync"

# Ensure the directory exists
if [ ! -d "${HOME}/Development/scripts" ]; then
    mkdir -p "${HOME}/Development/scripts"
    echo "Created directory ${HOME}/Development/scripts for configuration file."
fi

# Function to get password from Keychain
get_password() {
    security find-generic-password -w -a "$FTP_USER" -s "$KEYCHAIN_NAME"
}

# Function to store password in Keychain
store_password() {
    security add-generic-password -a "$FTP_USER" -s "$KEYCHAIN_NAME" -w "$1"
}

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    # Attempt to get password from keychain
    FTP_PASS=$(get_password)
else
    echo "Configuration file not found. Creating a new one..."

    read -p "Enter your Ashesi username: " FTP_USER
    read -sp "Enter your FTP password: " FTP_PASS
    echo
    read -p "Enter the local path to your lab/project directory: " LOCAL_DIR
    read -p "Enter the remote path on the server: " REMOTE_DIR

    # Store password in Keychain
    store_password "$FTP_PASS"
    
    # Save non-sensitive details to config file
    cat <<EOL > "$CONFIG_FILE"
FTP_USER="$FTP_USER"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
EOL

    echo "Configuration saved securely. You won't be asked for these details next time."
fi

# Rest of your sync script remains the same
echo "========================="
echo "FTP Host: $FTP_HOST"
echo "Port: $FTP_PORT" 
echo "Username: $FTP_USER"
echo "Local Directory: $LOCAL_DIR"
echo "Remote Directory: $REMOTE_DIR"
echo "========================="

# Function to sync files using lftp
sync_files() {
    echo "$(date '+%H:%M:%S') - Starting sync..."
    # Get password from keychain for each sync
    CURRENT_PASS=$(get_password)
    sync_output=$(lftp -u "$FTP_USER","$CURRENT_PASS" -p "$FTP_PORT" "$FTP_HOST" <<EOF
mirror -R --verbose --only-newer "$LOCAL_DIR" "$REMOTE_DIR"
quit
EOF
    )
    
    if [[ $sync_output == *"mirror:"* ]]; then
        echo "$sync_output" | grep "->" | while read -r line; do
            echo "$(date '+%H:%M:%S') - Synced file: $line"
        done
        echo "$(date '+%H:%M:%S') - Sync complete."
    else
        echo "$(date '+%H:%M:%S') - No new files to sync."
    fi
}

# Run initial sync
sync_files

# Monitor changes
fswatch -o "$LOCAL_DIR" | while read change; do
    echo "$(date '+%H:%M:%S') - Change detected. Syncing files..."
    sync_files
done