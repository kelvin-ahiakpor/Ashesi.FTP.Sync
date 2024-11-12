
# Ashesi FTP Sync

**Version:** 1.0

Ashesi FTP Sync is a cross-platform solution for automating file synchronization between local directories and Ashesi University’s FTP server. This script is ideal for students and developers working on web development projects, ensuring seamless and secure updates to the server in real-time.  

See [Demos](#demo) below.
---

## Features

- **Platform Compatibility**: Available for macOS and Windows.
- **Automated Synchronization**: Syncs files to the Ashesi FTP server whenever changes are detected.
- **Secure Credentials**:
  - macOS: Utilizes Keychain for password security.
  - Windows: Encrypts passwords using a secure key.
- **Real-Time Monitoring**:
  - macOS: Powered by `fswatch` for efficient file change detection.
  - Windows: Leverages FileSystemWatcher for event-based monitoring.
- **Simple Setup**: Intuitive configuration process saves user preferences for future runs.

---

## Requirements

### macOS/Linux
- **lftp**: Install with `brew install lftp` (macOS) or `sudo apt install lftp` (Linux).
- **fswatch**: Install with `brew install fswatch` (macOS) or `sudo apt install fswatch` (Linux).

### Windows
- **WinSCP**: Download and install [WinSCP](https://winscp.net/eng/download.php).

---

## Setup and Installation

### 1. Clone the Repository
Clone this repository to a directory of your choice:
```bash
git clone https://github.com/kelvin-ahiakpor/Ashesi.FTP.Sync.git
cd Ashesi.FTP.Sync
```

### 2. Usage
- **macOS/Linux**: 
    You may refer to the [macOS README](./README.md)
    Run the `sync_to_ftp.sh` file by navigating to its directory and executing:
    ```bash
    cd macOS
    chmod +x sync_to_ftp.sh
    ./sync_to_ftp.sh #strictly for your first run!
    ```

  * **Running after setup**: When you are done setting up the service will start running. But assuming you stop the service and start again use the following command:
    ```bash
    ./sync_to_ftp.sh & #subsequent runs can be in background with the added &
    ```

- **Windows**: 
    You may refer to the [Windows README](./README.md)
    Run the `sync_to_ftp.ps1` PowerShell script in this path \Ashesi.FTP.Sync\windows
    **Before Running on Windows**:
    - Open PowerShell as Administrator.
    - Allow scripts to run by executing:
        ```powershell
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
        ```

---

## Troubleshooting

1. **Configuration Issues**:
   - If incorrect details were entered during setup, remove the configuration file:
     - macOS: `rm ~/Development/scripts/sync_config.conf`
     - Windows: `Remove-Item -Path "$HOME\Development\scripts\sync_config.conf"`
   - Run the script again to reconfigure.

2. **Sync Issues**:
   - Ensure tools (`lftp`, `fswatch`, or WinSCP`) are properly installed and accessible in your system's PATH.

3. **Browser Cache**:
   - On macOS, hard refresh with **Cmd + Shift + R** or **Ctrl + F5** to see updated server files.

---

## Demo
Watch this [demo video] for macOS(https://youtu.be/LkYsw2BG1e4).
Watch this [demo video] for windows(https://youtu.be/ie83a7R-fuY).

---

## Next Steps

- **Version 2.0**: Support for syncing multiple directories.
- **Version 3.0**: Transitioning the script to a VS Code extension.

---

## Disclaimer

This project is tailored for Ashesi University students and is shared under an open-source license. Please ensure FTP credentials are stored securely and shared responsibly.
