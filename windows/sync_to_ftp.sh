#!/bin/bash

# Ashesi Server Constants
FTP_HOST="169.239.251.102"
FTP_PORT=321

# Path to the configuration file
CONFIG_DIR="$HOME/Development/scripts"
CONFIG_FILE="${CONFIG_DIR}/sync_config.conf"
LOCK_FILE="${TEMP}/sync_in_progress.lock"

# Check if required tools are installed
if ! command -v lftp &>/dev/null; then
    echo "lftp is not installed. Please install it using 'scoop install lftp'."
    exit 1
fi
if ! command -v watchman &>/dev/null; then
    echo "watchman is not installed. Please install it using 'scoop install watchman'."
    exit 1
fi

# Ensure the directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%H:%M:%S') - Created directory $CONFIG_DIR for configuration file."
fi

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    # Load user-specific details from the config file
    source "$CONFIG_FILE"
else
    # If the config file does not exist, create it and prompt for details
    echo "$(date '+%H:%M:%S') - Configuration file not found. Let's create one."

    # Prompt user for details
    read -p "Enter your Ashesi username: " FTP_USER
    read -sp "Enter your FTP password: " FTP_PASS
    echo
    read -p "Enter the local path to your lab/project directory (e.g., C:/path/to/lab): " LOCAL_DIR
    read -p "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING): " REMOTE_DIR

    # Convert forward slashes to backslashes for Windows compatibility
    LOCAL_DIR="${LOCAL_DIR//\//\\\\}"

    # Save details to the configuration file
    cat <<EOL > "$CONFIG_FILE"
FTP_USER="$FTP_USER"
FTP_PASS="$FTP_PASS"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
EOL

    chmod 600 "$CONFIG_FILE" # Restrict access to the config file
    echo "$(date '+%H:%M:%S') - Configuration saved. You are ready to sync!"
fi

# Function to sync files using lftp
sync_files() {
    echo "$(date '+%H:%M:%S') - Syncing files..."
    # Find and sync files using lftp
    find "$LOCAL_DIR" -type f | while read file; do
        # Convert file path to relative path for upload
        local relative_path="${file#${LOCAL_DIR}\\}"
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

# Use Watchman to monitor changes and run sync_files on change
watchman watch "$LOCAL_DIR"
watchman -- trigger "$LOCAL_DIR" sync -- "*" -- sh -c "
if [ ! -f \"$LOCK_FILE\" ]; then
    touch \"$LOCK_FILE\"
    echo \"$(date '+%H:%M:%S') - Change detected.\"
    sync_files
    rm \"$LOCK_FILE\"
else
    echo \"$(date '+%H:%M:%S') - Sync already in progress. Skipping...\"
fi
"
