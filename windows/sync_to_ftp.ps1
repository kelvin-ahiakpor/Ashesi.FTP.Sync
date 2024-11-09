# Path to the configuration directory and file within Development\scripts
$configDir = "$HOME\Development\scripts" 
$configFile = "$configDir\sync_config.conf"

# Ensure the directory exists
if (!(Test-Path -Path $configDir)) {
    New-Item -ItemType Directory -Path "$configDir" -Force
    Write-Host "Created directory $configDir for configuration file."
}

# Check if the configuration file exists
if (Test-Path -Path "$configFile") {
    # Load configuration from the file
    . "$configFile"
} else {
    # Prompt for configuration details on first run
    Write-Host "Configuration file not found. Creating a new one..."
    
    # Prompt the user for FTP credentials and paths
    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Read-Host "Enter your FTP password" #-AsSecureString | ConvertFrom-SecureString
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/lab5)"
    
    # Convert remote directory path to use backslashes on Windows
    $REMOTE_DIR = $REMOTE_DIR -replace "/", "\"

    # Save the details to the configuration file
    @"
`$FTP_USER = '$FTP_USER'
`$FTP_PASS = '$FTP_PASS'
`$LOCAL_DIR = '$LOCAL_DIR'
`$REMOTE_DIR = '$REMOTE_DIR'
"@ | Out-File -FilePath "$configFile" -Encoding UTF8

    Write-Host "Configuration saved to $configFile. You won't be asked for these details next time."
}

# Confirm details
Write-Host "========================="
Write-Host "FTP Host: 169.239.251.102"
Write-Host "Port: 321"
Write-Host "Username: $FTP_USER"
Write-Host "Local Directory: $LOCAL_DIR"
Write-Host "Remote Directory: $REMOTE_DIR"
Write-Host "========================="
Write-Host "Starting sync process..."

# Function to sync files using WinSCP with timestamped logs
function Sync-Files {
    $timeStamp = (Get-Date -Format "HH:mm:ss")
    $passPlainText = (New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList 'user', (ConvertTo-SecureString -String $FTP_PASS -AsPlainText -Force)).GetNetworkCredential().Password

    Write-Host "$timeStamp - Syncing files from $LOCAL_DIR to $REMOTE_DIR"

    # Run WinSCP sync command
    try {
        $syncResult = & "C:\Program Files (x86)\WinSCP\WinSCP.com" /log="$configDir\winscp.log" /loglevel=2 /command `
            "open ftp://${FTP_USER}:${passPlainText}@169.239.251.102:321" `
            "synchronize remote `"$REMOTE_DIR`" `"$LOCAL_DIR`" -mirror" `
            "exit"

        if ($syncResult -match "Transfer done") {
            Write-Host "$timeStamp - Sync complete."
        } else {
            Write-Host "$timeStamp - No new files to sync."
        }
    } catch {
        Write-Host "$timeStamp - ERROR: $($_.Exception.Message)" | Tee-Object -FilePath "$configDir\error.log" -Append
    }
}

# Run initial sync
Sync-Files

# Monitor for changes in the local directory
try {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = "$LOCAL_DIR"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite'

    # Register an event to trigger sync on change
    Register-ObjectEvent $watcher Changed -Action { 
        $timeStamp = (Get-Date -Format "HH:mm:ss")
        Write-Host "$timeStamp - Change detected. Syncing files..."
        Sync-Files 
    }

    $timeStamp = (Get-Date -Format "HH:mm:ss")
    Write-Host "$timeStamp Monitoring $LOCAL_DIR for changes..."

    # Keep the script running and display messages on screen
    while ($true) { Start-Sleep -Seconds 2 }
} catch {
    Write-Host "ERROR: Failed to set up directory monitoring. Check the path or permissions." | Tee-Object -FilePath "$configDir\error.log" -Append
}