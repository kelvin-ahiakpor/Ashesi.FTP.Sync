# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Path to the configuration file within Development/scripts
$SCRIPTS_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$SCRIPTS_DIR\sync_config.conf"
$LOG_FILE = "$SCRIPTS_DIR\sync_error.log"

# Ensure the directory exists
if (!(Test-Path $SCRIPTS_DIR)) {
    New-Item -ItemType Directory -Path $SCRIPTS_DIR | Out-Null
    Write-Host "Created directory $SCRIPTS_DIR for configuration file."
}

# Function to write to error log
function Write-ErrorLog {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $LOG_FILE
}

# Check if WinSCP .NET assembly is available
try {
    Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
} catch {
    Write-Host "Please install WinSCP and ensure WinSCPnet.dll is available"
    Write-ErrorLog "WinSCP .NET assembly not found: $_"
    exit 1
}

# Check if the configuration file exists
if (Test-Path $CONFIG_FILE) {
    # Load user-specific details from the config file
    Get-Content $CONFIG_FILE | ForEach-Object {
        if ($_ -match '(.+)="(.+)"') {
            Set-Variable -Name $matches[1] -Value $matches[2]
        }
    }
} else {
    # If the config file does not exist, create it and prompt for details
    Write-Host "Configuration file not found. Creating a new one..."

    # Prompt user for details
    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Read-Host "Enter your FTP password" -AsSecureString
    $FTP_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($FTP_PASS))
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"

    # Save the details to the configuration file
@"
FTP_USER="$FTP_USER"
FTP_PASS="$FTP_PASS"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
"@ | Out-File -FilePath $CONFIG_FILE -Encoding UTF8

    Write-Host "Configuration saved to $CONFIG_FILE. You won't be asked for these details next time."
}

# Confirm details
Write-Host "========================="
Write-Host "FTP Host: $FTP_HOST"
Write-Host "Port: $FTP_PORT"
Write-Host "Username: $FTP_USER"
Write-Host "Local Directory: $LOCAL_DIR"
Write-Host "Remote Directory: $REMOTE_DIR"
Write-Host "========================="
Write-Host "Starting sync process..."

# Function to sync files using WinSCP
function Sync-Files {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "$timestamp - Starting sync..."

    try {
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
        $sessionOptions.HostName = $FTP_HOST
        $sessionOptions.PortNumber = $FTP_PORT
        $sessionOptions.UserName = $FTP_USER
        $sessionOptions.Password = $FTP_PASS

        $session = New-Object WinSCP.Session
        $session.Open($sessionOptions)

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

        $result = $session.SynchronizeDirectories([WinSCP.SynchronizationMode]::Remote, $LOCAL_DIR, $REMOTE_DIR, $false, $false, [WinSCP.SynchronizationCriteria]::Time, $transferOptions)

        foreach ($transfer in $result.Transfers) {
            Write-Host "$timestamp - Synced file: $($transfer.FileName)"
        }

        if ($result.Transfers.Count -eq 0) {
            Write-Host "$timestamp - No new files to sync."
        }

    } catch {
        Write-Host "Error during sync: $_"
        Write-ErrorLog "Sync error: $_"
    } finally {
        if ($session) {
            $session.Dispose()
        }
    }
}

# Run initial sync
Sync-Files

# Use FileSystemWatcher to monitor changes
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $LOCAL_DIR
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$action = {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "$timestamp - Change detected. Syncing files..."
    Sync-Files
}

Register-ObjectEvent $watcher "Created" -Action $action
Register-ObjectEvent $watcher "Changed" -Action $action
Register-ObjectEvent $watcher "Deleted" -Action $action
Register-ObjectEvent $watcher "Renamed" -Action $action

Write-Host "Watching for changes. Press Ctrl+C to exit."
while ($true) { Start-Sleep -Seconds 1 }