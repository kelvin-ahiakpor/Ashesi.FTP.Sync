#!/bin/bash

# Ashesi Server Constants
FTP_HOST="169.239.251.102"
FTP_PORT=321

# Path to the configuration file within Development/scripts
CONFIG_FILE="${HOME}/Development/scripts/sync_config.conf"

# Ensure the directory exists
if [ ! -d "${HOME}/Development/scripts" ]; then
    mkdir -p "${HOME}/Development/scripts"
    echo "Created directory ${HOME}/Development/scripts for configuration file."
fi

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    # Load user-specific details from the config file
    source "$CONFIG_FILE"
else
    # If the config file does not exist, create it and prompt for details
    echo "Configuration file not found. Creating a new one..."

    # Prompt user for details
    read -p "Enter your Ashesi username: " FTP_USER
    read -sp "Enter your FTP password: " FTP_PASS #-sp for secure
    echo
    read -p "Enter the local path to your lab/project directory (e.g., /path/to/lab) DON'T USE "" or '' START WITH /: " LOCAL_DIR
    read -p "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING) - DON'T USE "" or '' START WITH /: " REMOTE_DIR

    # Save the details to the configuration file
    cat <<EOL > "$CONFIG_FILE"
FTP_USER="$FTP_USER"
FTP_PASS="$FTP_PASS"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
EOL

    echo "Configuration saved to $CONFIG_FILE. You won't be asked for these details next time."
fi

# Confirm details
echo "========================="
echo "FTP Host: $FTP_HOST"
echo "Port: $FTP_PORT"
echo "Username: $FTP_USER"
echo "Local Directory: $LOCAL_DIR"
echo "Remote Directory: $REMOTE_DIR"
echo "========================="
echo "Starting sync process..."

# Function to sync files using lftp
sync_files() {
    echo "$(date '+%H:%M:%S') - Starting sync..."
    # Run lftp sync and capture the output
    sync_output=$(lftp -u "$FTP_USER","$FTP_PASS" -p "$FTP_PORT" "$FTP_HOST" <<EOF
mirror -R --verbose --only-newer "$LOCAL_DIR" "$REMOTE_DIR"
quit
EOF
    )
    
    # Display which files were synced
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

# Use fswatch to monitor changes and run sync_files on change
fswatch -o "$LOCAL_DIR" | while read change; do
    echo "$(date '+%H:%M:%S') - Change detected. Syncing files..."
    sync_files
done
