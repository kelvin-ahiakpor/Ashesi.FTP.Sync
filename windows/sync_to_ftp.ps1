# Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321
$SCRIPTS_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$SCRIPTS_DIR\sync_config.conf"
$KEY_FILE = "$SCRIPTS_DIR\ftp_key"
$LOG_FILE = "$SCRIPTS_DIR\sync_error.log"

# Ensure the scripts directory exists
if (!(Test-Path $SCRIPTS_DIR)) {
    New-Item -ItemType Directory -Path $SCRIPTS_DIR | Out-Null
    Write-Host "Created directory $SCRIPTS_DIR for configuration file and key."
}

# Ensure the encryption key exists
if (!(Test-Path $KEY_FILE)) {
    $encryptionKey = (1..32 | ForEach-Object { [byte](Get-Random -Minimum 0 -Maximum 256) })
    $base64Key = [Convert]::ToBase64String($encryptionKey)
    $base64Key | Out-File -FilePath $KEY_FILE -Encoding UTF8
    Write-Host "Generated encryption key and saved to $KEY_FILE"
}

# Load encryption key
$encryptionKey = [Convert]::FromBase64String((Get-Content -Path $KEY_FILE -Raw))

# Functions for encryption and decryption
function Encrypt-String {
    param (
        [string]$plainText
    )
    $secureString = ConvertTo-SecureString -String $plainText -AsPlainText -Force
    $encrypted = ConvertFrom-SecureString -SecureString $secureString -Key $encryptionKey
    return $encrypted
}

function Decrypt-String {
    param (
        [string]$encryptedText
    )
    $secureString = ConvertTo-SecureString -String $encryptedText -Key $encryptionKey
    $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
    return $plainText
}

# Load configuration or prompt user for details
if (Test-Path $CONFIG_FILE) {
    $config = Import-Csv -Path $CONFIG_FILE -Delimiter '=' | ForEach-Object { @{ $_.Key = $_.Value } }
    $FTP_USER = $config["FTP_USER"]
    $FTP_PASS = Decrypt-String $config["FTP_PASS"]
    $LOCAL_DIR = $config["LOCAL_DIR"]
    $REMOTE_DIR = $config["REMOTE_DIR"]
} else {
    Write-Host "Configuration file not found. Creating a new one..."

    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Read-Host "Enter your FTP password" -AsSecureString
    $FTP_PASS_PLAIN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($FTP_PASS))
    $FTP_PASS_ENCRYPTED = Encrypt-String $FTP_PASS_PLAIN
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"

    # Save configuration
@"
FTP_USER=$FTP_USER
FTP_PASS=$FTP_PASS_ENCRYPTED
LOCAL_DIR=$LOCAL_DIR
REMOTE_DIR=$REMOTE_DIR
"@ | Set-Content -Path $CONFIG_FILE -Encoding UTF8

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

# Sync function using WinSCP
function Sync-Files {
    try {
        Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
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
            Write-Host "Synced file: $($transfer.FileName)"
        }

        if ($result.Transfers.Count -eq 0) {
            Write-Host "No new files to sync."
        }
    } catch {
        Write-Host "Error: $_"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - Error: $_" | Out-File -Append -FilePath $LOG_FILE
    } finally {
        if ($session) {
            $session.Dispose()
        }
    }
}

# Initial sync
Sync-Files

# Monitor changes with FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $LOCAL_DIR
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$onChange = {
    Write-Host "Change detected. Syncing files..."
    Sync-Files
}

Register-ObjectEvent $watcher -EventName "Changed" -Action $onChange
Register-ObjectEvent $watcher -EventName "Created" -Action $onChange
Register-ObjectEvent $watcher -EventName "Deleted" -Action $onChange
Register-ObjectEvent $watcher -EventName "Renamed" -Action $onChange

Write-Host "Watching for changes. Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 1 }
