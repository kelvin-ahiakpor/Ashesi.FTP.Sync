# Path to the configuration file within Development\scripts
$configDir = "$HOME\Development\scripts"
$configFile = "$configDir\sync_config.conf"

# Ensure the directory exists
if (!(Test-Path -Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force
    Write-Host "Created directory $configDir for configuration file."
}

# Check if the configuration file exists
if (Test-Path -Path $configFile) {
    # Load configuration from the file
    . $configFile
} else {
    # Prompt for configuration details on first run
    Write-Host "Configuration file not found. Creating a new one..."
    
    # Prompt the user for FTP credentials and paths
    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Read-Host "Enter your FTP password" -AsSecureString | ConvertFrom-SecureString
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\path\to\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/lab5)"

    # Save the details to the configuration file
    @"
`$FTP_USER = '$FTP_USER'
`$FTP_PASS = '$FTP_PASS'
`$LOCAL_DIR = '$LOCAL_DIR'
`$REMOTE_DIR = '$REMOTE_DIR'
"@ | Out-File -FilePath $configFile -Encoding UTF8

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

# Function to sync files using WinSCP
function Sync-Files {
    $passPlainText = (New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList 'user', (ConvertTo-SecureString -String $FTP_PASS -AsPlainText -Force)).GetNetworkCredential().Password

    & "C:\Program Files (x86)\WinSCP\WinSCP.com" /command `
        "open ftp://$FTP_USER:$passPlainText@169.239.251.102:321" `
        "synchronize remote $REMOTE_DIR $LOCAL_DIR -mirror" `
        "exit"
    
    if ($?) {
        Write-Host "Sync complete."
    } else {
        Write-Host "Sync failed. Check configuration or connection."
    }
}

# Run initial sync
Sync-Files

# Monitor for changes in the local directory
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $LOCAL_DIR
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite'

# Register an event to trigger sync on change
Register-ObjectEvent $watcher Changed -Action { Sync-Files }
Write-Host "Monitoring $LOCAL_DIR for changes..."

# Keep the script running
while ($true) { Start-Sleep -Seconds 10 }
