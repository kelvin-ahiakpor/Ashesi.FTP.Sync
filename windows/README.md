
# Ashesi FTP Sync (Windows)

## Overview

This project automates file synchronization on Windows, ensuring seamless updates between local project directories and a remote FTP server tailored for Ashesi University. It leverages WinSCP for secure file transfers and PowerShell's `FileSystemWatcher` for real-time monitoring of local file changes. User credentials are encrypted and stored securely, eliminating the need for plaintext passwords. Configuration is user-friendly, saving essential details for subsequent runs. Designed for web development workflows, the script ensures automated and secure synchronization with Windows-native tools.

## Prerequisites

Before using this script, ensure the following:
- **WinSCP**: Download and install from [WinSCP](https://winscp.net/eng/download.php).
- **PowerShell**: Installed by default on modern Windows versions.

## Installation and Setup

1. **Clone the Repository**:
    ```powershell
    git clone https://github.com/kelvin-ahiakpor/Ashesi.FTP.Sync.git
    cd Ashesi.FTP.Sync/windows
    ```

2. **Allow PowerShell Scripts**:
    Open PowerShell as Administrator and run:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
    ```

3. **Run the Script**:
    Execute the script and follow the prompts to enter:
    - **Ashesi Username**
    - **FTP Password** (encrypted and stored securely)
    - **Local Directory Path**
    - **Remote Directory Path**
    ```powershell
    .\sync_to_ftp.ps1
    ```

## Troubleshooting

- **WinSCP Installation**:
    Verify that `WinSCP.com` is correctly installed in:
    ```plaintext
    C:\Program Files (x86)\WinSCP    ```
- **Reset Configuration**:
    Delete the existing config file:
    ```powershell
    Remove-Item -Path "$HOME\Development\scripts\sync_config.conf"
    .\sync_to_ftp.ps1
    ```

## Next Steps

- Add multi-directory tracking in version 2.0.
- Explore a VS Code extension integration.
