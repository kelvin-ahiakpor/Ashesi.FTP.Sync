#!/bin/bash

# Ashesi Server Constants
FTP_HOST="169.239.251.102"
FTP_PORT=321

# Path to the configuration file within Development/scripts
CONFIG_DIR="${HOME}/Development/scripts"
CONFIG_FILE="${CONFIG_DIR}/sync_config.conf"
LOCK_FILE="/tmp/sync_in_progress.lock"

# Check if required tools are installed
if ! command -v lftp &>/dev/null; then
    echo "lftp is not installed. Please install it using 'brew install lftp' or 'sudo apt install lftp'."
    exit 1
fi
if ! command -v fswatch &>/dev/null; then
    echo "fswatch is not installed. Please install it using 'brew install fswatch' or 'sudo apt install fswatch'."
    exit 1
fi

# Ensure the directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%H:%M:%S') - Created directory $CONFIG_DIR for configuration file."
fi

# Function to test FTP connection
test_ftp_connection() {
    local user=$1
    local pass=$2
    echo "$(date '+%H:%M:%S') - Testing FTP connection..."
    
    # Try to connect and list directory
    if lftp -u "$user","$pass" -p "$FTP_PORT" "$FTP_HOST" -e "ls; quit" &>/dev/null; then
        echo "$(date '+%H:%M:%S') - Connection test successful!"
        return 0
    else
        echo "$(date '+%H:%M:%S') - Connection test failed. Please check your credentials."
        return 1
    fi
}

# Function to store credentials in Keychain
store_credentials() {
    # First test the connection
    if ! test_ftp_connection "$FTP_USER" "$FTP_PASS"; then
        echo "$(date '+%H:%M:%S') - Aborting credential storage due to failed connection test."
        exit 1
    fi

    # Remove existing keychain entry if it exists
    security delete-generic-password -a "$FTP_USER" -s "Ashesi FTP" &>/dev/null

    # Store the new username and password
    security add-generic-password -a "$FTP_USER" -s "Ashesi FTP" -w "$FTP_PASS"
    echo "$(date '+%H:%M:%S') - Credentials stored securely in Keychain."
}

# Function to retrieve password from Keychain
retrieve_password() {
    security find-generic-password -a "$FTP_USER" -s "Ashesi FTP" -w 2>/dev/null
}

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    # Load user-specific details from the config file
    source "$CONFIG_FILE"
    FTP_PASS=$(retrieve_password)

    # Verify stored credentials still work
    if ! test_ftp_connection "$FTP_USER" "$FTP_PASS"; then
        echo "$(date '+%H:%M:%S') - Stored credentials are invalid. Please run again to enter credentials."
        rm "$CONFIG_FILE"
        exit 1
    fi
else
    # If the config file does not exist, create it and prompt for details
    echo "$(date '+%H:%M:%S') - Configuration file not found. Let's create one."

    while true; do
        # Prompt user for details
        read -p "Enter your Ashesi username: " FTP_USER
        read -sp "Enter your FTP password: " FTP_PASS
        echo
        
        # Test connection before proceeding
        if test_ftp_connection "$FTP_USER" "$FTP_PASS"; then
            break
        else
            echo "Please try again with correct credentials."
        fi
    done

    read -p "Enter the local path to your lab/project directory (e.g., /path/to/lab): " LOCAL_DIR
    read -p "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING): " REMOTE_DIR

    # Store credentials in Keychain
    store_credentials

    # Save non-sensitive details to the configuration file
    cat <<EOL > "$CONFIG_FILE"
FTP_USER="$FTP_USER"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
EOL

    chmod 600 "$CONFIG_FILE" # Restrict access to the config file
    echo "$(date '+%H:%M:%S') - Configuration saved. You are ready to sync!"
fi

# Function to sync files using lftp
sync_files() {
    echo "$(date '+%H:%M:%S') - Syncing files..."
    find "$LOCAL_DIR" -type f -newermt "$(date -v-1S '+%Y-%m-%d %H:%M:%S')" | while read file; do
        local relative_path="${file#$LOCAL_DIR/}"
        lftp -u "$FTP_USER","$FTP_PASS" -p "$FTP_PORT" "$FTP_HOST" <<EOF
put "$file" -o "$REMOTE_DIR/$relative_path"
quit
EOF
        echo "$(date '+%H:%M:%S') - Synced file: $file"
    done
    echo "$(date '+%H:%M:%S') - Sync complete."
}

# Run initial sync
sync_files

# Use fswatch to monitor changes and run sync_files on change
fswatch -r -l 0.5 "$LOCAL_DIR" | while read change; do
    if [ ! -f "$LOCK_FILE" ]; then
        touch "$LOCK_FILE"
        echo "$(date '+%H:%M:%S') - Change detected."
        sync_files
        rm "$LOCK_FILE"
    else
        echo "$(date '+%H:%M:%S') - Sync already in progress. Skipping..."
    fi
done
