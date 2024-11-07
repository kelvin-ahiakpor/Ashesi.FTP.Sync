
# Ashesi FTP Sync 

Automatically track changes in your code base and upload to FileZilla FTP Server.

## Demo
Watch this [video](https://youtube.com)

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
    - **FTP Password** The one you use for ssh/FileZilla (Check Simon's email)
    - **Local Directory Path**: Path to your lab/project directory.
    - **Remote Directory Path**: Path on the server where the files will be synced.

    These details will be saved in `sync_config.conf` within this folder, so everything stays organized.

## Usage

- **macOS/Linux**: Run the `sync_script.sh` file by navigating to its directory and executing:
    ```bash
    cd macOS
    chmod +x sync_to_ftp.sh
    ./sync_to_ftp.sh #strictly for your first run!
    ```

  * **Running after setup**: When you are done setting up the service will start running. But assuming you stop the service and start gain use the following command:
    ```bash
    ./sync_to_ftp.sh & #subsequent runs can be in background with the added &
    ```

- **Windows**: Run the `sync_script.ps1` PowerShell script. Directory Monitor can be configured to trigger `sync_script.ps1` on changes if desired.
To find `sync_script.ps1`. Follow this path \Ashesi.FTP.Sync\windows

## Example Configuration

An example `sync_config.conf`:

```conf
FTP_USER="your_username"
FTP_PASS="your_password"
LOCAL_DIR="/path/to/local/directory" # Use format C:\path\to\directory for Windows
REMOTE_DIR="/path/to/remote/directory" # Do not put quoutes ("" or '' around your path)
```

## Help with images
Here is what your remote directory looks like in Filezilla:
![Filezilla1](https://github.com/kelvin-ahiakpor/kelvin-ahiakpor.github.io/blob/main/images/ftpsync1.png)

## Troubleshooting

- **macOS/Linux**: Ensure `lftp` and `fswatch` are installed and configured properly.
- **Windows**: Verify that WinSCP is correctly installed and Directory Monitor (if used) is configured to track changes.
- **Mistake in initial setup**: Maybe you used the wrong password or path initially. To fix, run the following commands:
```bash
rm ~/Development/scripts/sync_config.conf
./sync_to_ftp.sh
```

## Notes

This script is designed to assist in automating the sync process for WebTech projects and assignments on the Ashesi server.
While using on macOS, I realized that after about an hour, the browser stops retrieving the updated files. 
It seems like a browser caching problem. To fix, do a 'hard refresh' using  Ctrl + F5 or Cmd + Shift + R.
In other cases you may want to restart your browser or laptop (quite undesirable, so try the hard refresh many times). 

**Extra**:
On macOS this script is run as a job. Here is how to manuever:

```bash
jobs # view all running jobs
kill %1 # kill first job. this stops the script if it is the first job.  
./sync_script.sh & # restart the job if needed.
```

---

## PS: 
You can also try killing and restarting the job (on macOS) to see if that solves the caching issue, I doubt though.
I have not tested this script extensively on Windows so kindly send your bug reports on kelvin.ahiakpor@ashesi.edu.gh

---

### Disclaimer

Please ensure your FTP credentials are kept secure and only share this script with trusted individuals.
