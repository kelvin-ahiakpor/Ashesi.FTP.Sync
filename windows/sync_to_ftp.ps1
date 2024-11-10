# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Load the WinSCP .NET Assembly
Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

# Path to the configuration file
$CONFIG_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$CONFIG_DIR\sync_config.conf"

# Ensure the configuration directory exists
if (!(Test-Path $CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CONFIG_DIR | Out-Null
    Write-Host "$(Get-Date -Format HH:mm:ss) - Created directory $CONFIG_DIR for configuration file."
}

# Function to encrypt text
function Protect-Text {
    param([string]$Text)
    $secureString = ConvertTo-SecureString $Text -AsPlainText -Force
    return $secureString | ConvertFrom-SecureString
}

# Function to decrypt text
function Unprotect-Text {
    param([string]$EncryptedText)
    $secureString = $EncryptedText | ConvertTo-SecureString
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
}

# Function to sync files using WinSCP
function Sync-Files {
    param($FTP_USER, $FTP_PASS, $LOCAL_DIR, $REMOTE_DIR)
    Write-Host "$(Get-Date -Format HH:mm:ss) - Starting sync..."
    try {
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
        $sessionOptions.HostName = $FTP_HOST
        $sessionOptions.PortNumber = $FTP_PORT
        $sessionOptions.UserName = $FTP_USER
        $sessionOptions.Password = $FTP_PASS

        # Enable session logging
        $session = New-Object WinSCP.Session
        $session.SessionLogPath = "$env:USERPROFILE\Development\scripts\ftp_session.log"
        $session.Open($sessionOptions)

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

        $result = $session.SynchronizeDirectories(
            [WinSCP.SynchronizationMode]::Remote,
            $LOCAL_DIR,
            $REMOTE_DIR,
            $false, $false, [WinSCP.SynchronizationCriteria]::Time, $transferOptions
        )

        foreach ($transfer in $result.Transfers) {
            Write-Host "$(Get-Date -Format HH:mm:ss) - Synced file: $($transfer.FileName)"
        }

        if ($result.Transfers.Count -eq 0) {
            Write-Host "$(Get-Date -Format HH:mm:ss) - No new files to sync."
        }
    } catch {
        Write-Host "Error during sync: $_"
    } finally {
        if ($session) {
            $session.Dispose()
        }
    }
}


# Initial setup: Load or create configuration
if (Test-Path $CONFIG_FILE) {
    $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
    $FTP_USER = $config.FTP_USER
    $FTP_PASS = Unprotect-Text $config.FTP_PASS
    $LOCAL_DIR = $config.LOCAL_DIR
    $REMOTE_DIR = $config.REMOTE_DIR
} else {
    Write-Host "Configuration file not found. Creating a new one..."

    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Protect-Text (Read-Host "Enter your FTP password" -AsSecureString)
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"

    $config = @{
        FTP_USER = $FTP_USER
        FTP_PASS = $FTP_PASS
        LOCAL_DIR = $LOCAL_DIR
        REMOTE_DIR = $REMOTE_DIR
    }
    $config | ConvertTo-Json | Set-Content -Path $CONFIG_FILE
    Write-Host "Configuration saved to $CONFIG_FILE."
}

# Confirm details
Write-Host "========================="
Write-Host "FTP Host: $FTP_HOST"
Write-Host "Port: $FTP_PORT"
Write-Host "Username: $FTP_USER"
Write-Host "Local Directory: $LOCAL_DIR"
Write-Host "Remote Directory: $REMOTE_DIR"
Write-Host "========================="

# Run initial sync
Sync-Files -FTP_USER $FTP_USER -FTP_PASS (Unprotect-Text $FTP_PASS) -LOCAL_DIR $LOCAL_DIR -REMOTE_DIR $REMOTE_DIR

# Use FileSystemWatcher to monitor changes
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $LOCAL_DIR
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$action = {
    Write-Host "$(Get-Date -Format HH:mm:ss) - Change detected. Syncing files..."
    Sync-Files -FTP_USER $FTP_USER -FTP_PASS (Unprotect-Text $FTP_PASS) -LOCAL_DIR $LOCAL_DIR -REMOTE_DIR $REMOTE_DIR
}

Register-ObjectEvent $watcher "Changed" -Action $action

Write-Host "Watching for changes. Press Ctrl+C to exit."
while ($true) { Start-Sleep -Seconds 1 }
