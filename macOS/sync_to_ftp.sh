#!/bin/bash

# Ashesi Server Constants
FTP_HOST="169.239.251.102"
FTP_PORT=321

# Path to the configuration file and key file within Development/scripts
CONFIG_DIR="${HOME}/Development/scripts"
CONFIG_FILE="${CONFIG_DIR}/sync_config.conf"
KEY_FILE="${CONFIG_DIR}/ftp_key"

# Ensure the directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo "Created directory $CONFIG_DIR for configuration file and key."
fi

# Ensure the key file exists
if [ ! -f "$KEY_FILE" ]; then
    # Generate a random key and save it to the key file
    head -c 32 /dev/urandom | base64 > "$KEY_FILE"
    chmod 600 "$KEY_FILE" # Restrict access to the key file
    echo "Generated encryption key and saved to $KEY_FILE"
fi

# Function to encrypt a string
encrypt() {
    local plaintext="$1"
    local key=$(cat "$KEY_FILE")
    echo "$plaintext" | openssl enc -aes-256-cbc -a -salt -pass pass:"$key"
}

# Function to decrypt a string
decrypt() {
    local ciphertext="$1"
    local key=$(cat "$KEY_FILE")
    echo "$ciphertext" | openssl enc -aes-256-cbc -a -d -pass pass:"$key"
}

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    # Load user-specific details from the config file
    source "$CONFIG_FILE"
    FTP_PASS=$(decrypt "$FTP_PASS_ENCRYPTED")
else
    # If the config file does not exist, create it and prompt for details
    echo "Configuration file not found. Creating a new one..."

    # Prompt user for details
    read -p "Enter your Ashesi username: " FTP_USER
    read -sp "Enter your FTP password: " FTP_PASS
    echo
    read -p "Enter the local path to your lab/project directory (e.g., /path/to/lab): " LOCAL_DIR
    read -p "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING): " REMOTE_DIR

    # Encrypt the password
    FTP_PASS_ENCRYPTED=$(encrypt "$FTP_PASS")

    # Save the details to the configuration file
    cat <<EOL > "$CONFIG_FILE"
FTP_USER="$FTP_USER"
FTP_PASS_ENCRYPTED="$FTP_PASS_ENCRYPTED"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
EOL

    chmod 600 "$CONFIG_FILE" # Restrict access to the config file
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
    sync_output=$(lftp -u "$FTP_USER","$FTP_PASS" -p "$FTP_PORT" "$FTP_HOST" <<EOF
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

# Use fswatch to monitor changes and run sync_files on change
fswatch -o "$LOCAL_DIR" | while read change; do
    echo "$(date '+%H:%M:%S') - Change detected. Syncing files..."
    sync_files
done
