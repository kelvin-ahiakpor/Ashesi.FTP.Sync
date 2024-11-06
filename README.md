# Ashesi.FTP.Sync
Automatically track changes in your code base and upload to FileZilla FTP Server.

This Bash script automates the process of syncing a local project or lab directory to the Ashesi server. It uses `lftp` to mirror files from a local directory to a remote server directory, only syncing files that have been modified. Additionally, it monitors the local directory for changes using `fswatch` and triggers a sync whenever a change is detected.

## Features

- **Configuration file**: Saves your Ashesi username, password, local directory, and remote directory details in a configuration file (`sync_config.conf`) for easy reuse.
- **Automated Sync**: Automatically syncs files to the Ashesi server when they are modified locally.
- **Change Monitoring**: Uses `fswatch` to monitor the local directory for changes and syncs automatically.

## Requirements

- `lftp`: Install it via `sudo apt install lftp`.
- `fswatch`: Install it via `brew install fswatch` on macOS, or `sudo apt install fswatch` on Ubuntu.

## Installation

1. Clone this repository to your local machine.
2. Make the script executable by running:

    ```bash
    chmod +x sync_script.sh
    ```

3. Run the script:

    ```bash
    ./sync_script.sh
    ```

## Configuration

If the script is run for the first time, it will prompt you for the following details:
- **Ashesi Username**
- **FTP Password**
- **Local Directory Path**: Path to your lab/project directory.
- **Remote Directory Path**: Path on the server where the files will be synced.

The details will be saved in `sync_config.conf` in your home directory. You can edit this file later if needed.

## Usage

- Run the script with `./sync_script.sh`.
- The script will sync all modified files to the Ashesi server and monitor the local directory for any changes.
- When a change is detected, the script will sync only the changed files.

## Example Configuration

An example `sync_config.conf`:

```conf
FTP_USER="your_username"
FTP_PASS="your_password"
LOCAL_DIR="/path/to/local/directory"
REMOTE_DIR="/path/to/remote/directory"
```

## Troubleshooting

- Ensure that `lftp` and `fswatch` are installed and properly configured.
- If permissions issues occur, check the script's executable permissions or run as sudo if necessary.

## Notes

This script was created to assist students in automating the sync process for WebTech projects and assignments.

---

### Disclaimer

Please ensure your FTP credentials are kept secure and only share this script with trusted individuals.

