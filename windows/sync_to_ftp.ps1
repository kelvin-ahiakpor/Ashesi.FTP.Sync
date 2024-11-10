# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Path to the configuration file within Development/scripts
$SCRIPTS_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$SCRIPTS_DIR\sync_config.conf"
$LOG_FILE = "$SCRIPTS_DIR\sync_error.log"
$KEY_FILE = "$SCRIPTS_DIR\sync.key"

# Sync control variables
$script:lastSyncTime = [DateTime]::MinValue
$script:changeQueue = @{}
$script:syncInProgress = $false
$SYNC_DELAY = 2 # Seconds to wait after detecting changes before syncing

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
    Write-Host "$timestamp - ERROR: $message" -ForegroundColor Red
}

# Function to write success log
function Write-SuccessLog {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - SUCCESS: $message" -ForegroundColor Green
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

# Load or create configuration
try {
    # Check if the configuration file exists
    if (Test-Path $CONFIG_FILE) {
        # Load user-specific details from the config file
        $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
        $script:FTP_USER = $config.FTP_USER
        $script:FTP_PASS = Unprotect-Text $config.FTP_PASS
        $script:LOCAL_DIR = $config.LOCAL_DIR
        $script:REMOTE_DIR = $config.REMOTE_DIR
    } else {
        # If the config file does not exist, create it and prompt for details
        Write-Host "Configuration file not found. Let's create one."

        # Prompt user for details
        $script:FTP_USER = Read-Host "Enter your Ashesi username"
        $securePass = Read-Host "Enter your FTP password" -AsSecureString
        $script:FTP_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
        $script:LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
        $script:REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"

        # Encrypt password and save configuration
        $encryptedPass = Protect-Text $FTP_PASS
        $config = @{
            FTP_USER = $FTP_USER
            FTP_PASS = $encryptedPass
            LOCAL_DIR = $LOCAL_DIR
            REMOTE_DIR = $REMOTE_DIR
        }

        $config | ConvertTo-Json | Set-Content -Path $CONFIG_FILE
        Write-SuccessLog "Configuration saved successfully!"
    }
}
catch {
    Write-ErrorLog "Failed to load or create configuration: $_"
    exit 1
}

# Function to verify FTP connection
function Test-FTPConnection {
    try {
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
        $sessionOptions.HostName = $FTP_HOST
        $sessionOptions.PortNumber = $FTP_PORT
        $sessionOptions.UserName = $FTP_USER
        $sessionOptions.Password = $FTP_PASS

        $session = New-Object WinSCP.Session
        $session.Open($sessionOptions)
        $session.Dispose()
        return $true
    }
    catch {
        Write-ErrorLog "FTP connection test failed: $_"
        return $false
    }
}

# Function to sync files using WinSCP with retry mechanism
function Sync-Files {
    if ($script:syncInProgress) {
        Write-Host "Sync already in progress, skipping..." -ForegroundColor Yellow
        return
    }

    $script:syncInProgress = $true
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "$timestamp - Starting sync..." -ForegroundColor Cyan

    try {
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
        $sessionOptions.HostName = $FTP_HOST
        $sessionOptions.PortNumber = $FTP_PORT
        $sessionOptions.UserName = $FTP_USER
        $sessionOptions.Password = $FTP_PASS
        $sessionOptions.TimeoutInMilliseconds = 30000  # 30 second timeout

        $session = New-Object WinSCP.Session
        $session.Open($sessionOptions)

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
        $transferOptions.ResumeSupport.State = [WinSCP.TransferResumeSupportState]::On
        
        # Set synchronization criteria to Time
        $result = $session.SynchronizeDirectories(
            [WinSCP.SynchronizationMode]::Remote, 
            $LOCAL_DIR, 
            $REMOTE_DIR, 
            $false,  # Remove files that don't exist locally
            $false,  # Preview only
            [WinSCP.SynchronizationCriteria]::Time,  # Use time criteria
            $transferOptions
        )

        # Verify transfers
        $failedTransfers = $result.Transfers | Where-Object { -not $_.IsSuccess }
        
        if ($failedTransfers) {
            foreach ($transfer in $failedTransfers) {
                Write-ErrorLog "Failed to sync: $($transfer.FileName) - $($transfer.Error)"
            }
        }

        $successfulTransfers = $result.Transfers | Where-Object { $_.IsSuccess }
        foreach ($transfer in $successfulTransfers) {
            Write-SuccessLog "Synced file: $($transfer.FileName)"
        }

        if ($result.Transfers.Count -eq 0) {
            Write-Host "$timestamp - No new files to sync." -ForegroundColor Gray
        }

    }
    catch {
        Write-ErrorLog "Sync error: $_"
        
        # Retry once on failure
        try {
            Start-Sleep -Seconds 2
            Write-Host "Retrying sync..." -ForegroundColor Yellow
            $result = $session.SynchronizeDirectories(
                [WinSCP.SynchronizationMode]::Remote, 
                $LOCAL_DIR, 
                $REMOTE_DIR, 
                $false, 
                $false,
                [WinSCP.SynchronizationCriteria]::Time,
                $transferOptions
            )
            Write-SuccessLog "Retry successful"
        }
        catch {
            Write-ErrorLog "Retry failed: $_"
        }
    }
    finally {
        if ($session) {
            $session.Dispose()
        }
        $script:syncInProgress = $false
        $script:lastSyncTime = Get-Date
    }
}

# Changed file handler with debouncing
$action = {
    param($source, $e)
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fileName = $e.Name
    $changeType = $e.ChangeType
    
    Write-Host "$timestamp - Change detected: $changeType - $fileName" -ForegroundColor Yellow
    
    # Add to change queue
    $script:changeQueue[$fileName] = $changeType
    
    # Check if we should sync
    $timeSinceLastSync = (Get-Date) - $script:lastSyncTime
    if ($timeSinceLastSync.TotalSeconds -ge $SYNC_DELAY -and -not $script:syncInProgress) {
        Write-Host "Processing queued changes..." -ForegroundColor Cyan
        $script:changeQueue.Clear()  # Clear the queue
        Start-Sleep -Seconds 1  # Small delay to ensure file operations are complete
        Sync-Files
    }
}

# Main script execution
try {
    # Confirm details
    Write-Host "`n========================="
    Write-Host "FTP Host: $FTP_HOST"
    Write-Host "Port: $FTP_PORT"
    Write-Host "Username: $FTP_USER"
    Write-Host "Local Directory: $LOCAL_DIR"
    Write-Host "Remote Directory: $REMOTE_DIR"
    Write-Host "=========================`n"

    # Test FTP connection before starting
    if (-not (Test-FTPConnection)) {
        throw "Unable to establish FTP connection. Please check your credentials and connection."
    }

    # Run initial sync
    Sync-Files

    # Set up file system watcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $LOCAL_DIR
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # Register for change events
    Register-ObjectEvent $watcher "Created" -Action $action
    Register-ObjectEvent $watcher "Changed" -Action $action
    Register-ObjectEvent $watcher "Deleted" -Action $action
    Register-ObjectEvent $watcher "Renamed" -Action $action

    Write-Host "`nWatching for changes in $LOCAL_DIR" -ForegroundColor Green
    Write-Host "Press Ctrl+C to exit.`n" -ForegroundColor Yellow

    # Main loop with periodic forced sync
    while ($true) {
        Start-Sleep -Seconds 1
        
        # Force sync every 5 minutes if there are queued changes
        $timeSinceLastSync = (Get-Date) - $script:lastSyncTime
        if ($script:changeQueue.Count -gt 0 -and $timeSinceLastSync.TotalSeconds -ge 300) {
            Write-Host "Performing periodic sync of queued changes..." -ForegroundColor Cyan
            $script:changeQueue.Clear()
            Sync-Files
        }
    }
}
catch {
    Write-ErrorLog "Fatal error: $_"
    exit 1
}
finally {
    # Cleanup
    Get-EventSubscriber | Unregister-Event
}