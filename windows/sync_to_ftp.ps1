# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Path to the configuration file within Development/scripts
$SCRIPTS_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$SCRIPTS_DIR\sync_config.conf"
$LOG_FILE = "$SCRIPTS_DIR\sync_error.log"
$KEY_FILE = "$SCRIPTS_DIR\sync.key"


# Check if WinSCP is installed
if (!(Test-Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll")) {
    Write-Host "WinSCP is not installed. Please download it from https://winscp.net/eng/download.php"
    exit 1
}

# Ensure the directory exists
if (!(Test-Path $SCRIPTS_DIR)) {
    New-Item -ItemType Directory -Path $SCRIPTS_DIR | Out-Null
}

# Function to write to error log
function Write-ErrorLog {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $LOG_FILE
}

# Function to create encryption key
function New-EncryptionKey {
    $Key = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
    $Key | Set-Content $KEY_FILE -Encoding Byte
    return $Key
}

# Function to get encryption key
function Get-EncryptionKey {
    if (!(Test-Path $KEY_FILE)) {
        return New-EncryptionKey
    }
    return Get-Content $KEY_FILE -Encoding Byte
}

# Function to encrypt text
function Protect-Text {
    param([string]$Text)
    
    try {
        $Key = Get-EncryptionKey
        $secureString = ConvertTo-SecureString $Text -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString $secureString -Key $Key
        return $encrypted
    }
    catch {
        Write-ErrorLog "Encryption error: $_"
        throw
    }
}

# Function to decrypt text
function Unprotect-Text {
    param([string]$EncryptedText)
    
    try {
        $Key = Get-EncryptionKey
        $secureString = ConvertTo-SecureString $EncryptedText -Key $Key
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    catch {
        Write-ErrorLog "Decryption error: $_"
        throw
    }
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
    $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
    $FTP_USER = $config.FTP_USER
    $FTP_PASS = Unprotect-Text $config.FTP_PASS
    $LOCAL_DIR = $config.LOCAL_DIR
    $REMOTE_DIR = $config.REMOTE_DIR
} else {
    # If the config file does not exist, create it and prompt for details
    Write-Host "Configuration file not found. Let's create one."

    # Prompt user for details
    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Read-Host "Enter your FTP password" -AsSecureString
    $FTP_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($FTP_PASS))
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"

    # Encrypt password and save configuration
    $encryptedPass = Protect-Text $FTP_PASS
    $config = @{
        FTP_USER = $FTP_USER
        FTP_PASS = $encryptedPass
        LOCAL_DIR = $LOCAL_DIR
        REMOTE_DIR = $REMOTE_DIR
    }

    $config | ConvertTo-Json | Set-Content -Path $CONFIG_FILE

    Write-Host "Configuration saved. You're ready to sync! No details required next time."
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
while ($true) { Start-Sleep -Seconds 0.2 }