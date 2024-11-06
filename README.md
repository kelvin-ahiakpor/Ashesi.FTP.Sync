
# Ashesi FTP Sync 

Automatically track changes in your code base and upload to FileZilla FTP Server.
Depending on your OS, you can use the appropriate script to automate file syncing and monitor changes.

## Features

- **Configuration file**: Saves your Ashesi username, password, local directory, and remote directory details in a configuration file (`sync_config.conf`) for easy reuse.
- **Automated Sync**: Syncs files to the Ashesi server when modified locally.
- **Change Monitoring**: Monitors the local directory for changes and syncs automatically.

## Requirements

### For macOS/Linux

- `lftp`: Install it via `brew install lftp` (macOS) or `sudo apt install lftp` (Linux).
- `fswatch`: Install it via `brew install fswatch` (macOS) or `sudo apt install fswatch` (Linux).

### For Windows

- **WinSCP**: Download and install [WinSCP](https://winscp.net/eng/download.php) for secure file transfer.
- **Directory Monitor (Optional)**: [Directory Monitor](https://directorymonitor.com/download) can be used to detect file changes on Windows.

## Setup and Configuration

1. **Clone the Repository**: Begin by cloning this repository into a desired folder on your system to keep the script and configuration file organized.
    ```bash
    git clone https://github.com/kelvin-ahiakpor/Ashesi.FTP.Sync.git
    cd Ashesi.FTP.Sync
    ```

2. **Initial Run**: The first time you run the script, it will prompt you to enter the following details:
    - **Ashesi Username**
    - **FTP Password**
    - **Local Directory Path**: Path to your lab/project directory.
    - **Remote Directory Path**: Path on the server where the files will be synced.

    These details will be saved in `sync_config.conf` within this folder, so everything stays organized.

## Usage

- **macOS/Linux**: Run the `sync_script.sh` file by navigating to its directory and executing:
    ```bash
    chmod +x sync_to_ftp.sh
    ./sync_script.sh &
    ```

- **Windows**: Run the `sync_script.ps1` PowerShell script. Directory Monitor can be configured to trigger `sync_script.ps1` on changes if desired.

## Example Configuration

An example `sync_config.conf`:

```conf
FTP_USER="your_username"
FTP_PASS="your_password"
LOCAL_DIR="/path/to/local/directory" # Use format C:\path\to\directory for Windows
REMOTE_DIR="/path/to/remote/directory"
```

## Troubleshooting

- **macOS/Linux**: Ensure `lftp` and `fswatch` are installed and configured properly.
- **Windows**: Verify that WinSCP is correctly installed and Directory Monitor (if used) is configured to track changes.

## Notes

This script is designed to assist students in automating the sync process for WebTech projects and assignments on the Ashesi server.
On macOS this script is run as a job. Here is how to manuever.
    ```bash
    jobs # view all running jobs
    kill %1 # kill first job. this stops the script if it is the first job.  
    ```
---

### Disclaimer

Please ensure your FTP credentials are kept secure and only share this script with trusted individuals.
