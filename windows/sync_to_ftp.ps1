# Ashesi.FTP.Sync/windows/sync_to_ftp.ps1

# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = "321"

# Configuration paths
$CONFIG_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$CONFIG_DIR\sync_config.conf"
$WINSCP_PATH = "C:\Program Files (x86)\WinSCP\WinSCP.com"

# Ensure WinSCP is installed
if (-not (Test-Path $WINSCP_PATH)) {
    Write-Host "WinSCP is not installed in the expected location: $WINSCP_PATH"
    Write-Host "Please install WinSCP from https://winscp.net/eng/download.php"
    exit 1
}

# Create config directory if it doesn't exist
if (-not (Test-Path $CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CONFIG_DIR | Out-Null
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Created directory $CONFIG_DIR for configuration file."
}

# Function to securely store credentials
function Save-Credentials {
    param (
        [string]$username,
        [SecureString]$password
    )
    
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
    $credentials | Export-Clixml -Path "$CONFIG_DIR\credentials.xml"
}

# Function to retrieve credentials
function Get-StoredCredentials {
    if (Test-Path "$CONFIG_DIR\credentials.xml") {
        Import-Clixml -Path "$CONFIG_DIR\credentials.xml"
    }
    else {
        return $null
    }
}

# Function to sync files using WinSCP
function Sync-Files {
    param (
        [string]$localPath,
        [string]$remotePath,
        [string]$username,
        [SecureString]$password
    )

    # Create WinSCP script
    $scriptContent = @"
option batch on
option confirm off
open ftp://${username}:${password}@${FTP_HOST}:${FTP_PORT}
synchronize remote "$localPath" "$remotePath"
exit
"@

    # Save script to temporary file
    $tempScript = [System.IO.Path]::GetTempFileName()
    $scriptContent | Out-File -FilePath $tempScript -Encoding ASCII

    # Execute WinSCP with the script
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Syncing files..."
    & $WINSCP_PATH /script="$tempScript" /log="$CONFIG_DIR\winscp.log"

    # Clean up
    Remove-Item $tempScript
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Sync complete."
}

# Check if configuration exists
if (Test-Path $CONFIG_FILE) {
    # Load existing configuration
    $config = Get-Content $CONFIG_FILE | ConvertFrom-StringData
    $credentials = Get-StoredCredentials
    $FTP_USER = $config.FTP_USER
    $LOCAL_DIR = $config.LOCAL_DIR
    $REMOTE_DIR = $config.REMOTE_DIR
    $FTP_PASS = $credentials.GetNetworkCredential().Password
}
else {
    # Create new configuration
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Configuration file not found. Let's create one."
    
    $FTP_USER = Read-Host "Enter your Ashesi username"
    $FTP_PASS = Read-Host "Enter your FTP password" -AsSecureString
    $LOCAL_DIR = Read-Host "Enter the local path to your lab/project directory (e.g., C:\Projects\lab)"
    $REMOTE_DIR = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"

    # Store credentials securely
    Save-Credentials -username $FTP_USER -password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($FTP_PASS)))

    # Save configuration
    @"
FTP_USER=$FTP_USER
LOCAL_DIR=$LOCAL_DIR
REMOTE_DIR=$REMOTE_DIR
"@ | Out-File -FilePath $CONFIG_FILE -Encoding ASCII

    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Configuration saved. You are ready to sync!"
}

# Initial sync
Sync-Files -localPath $LOCAL_DIR -remotePath $REMOTE_DIR -username $FTP_USER -password $FTP_PASS

# Start file system watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $LOCAL_DIR
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$changed = Register-ObjectEvent $watcher "Changed" -Action {
    Sync-Files -localPath $LOCAL_DIR -remotePath $REMOTE_DIR -username $FTP_USER -password $FTP_PASS
}
$created = Register-ObjectEvent $watcher "Created" -Action {
    Sync-Files -localPath $LOCAL_DIR -remotePath $REMOTE_DIR -username $FTP_USER -password $FTP_PASS
}
$deleted = Register-ObjectEvent $watcher "Deleted" -Action {
    Sync-Files -localPath $LOCAL_DIR -remotePath $REMOTE_DIR -username $FTP_USER -password $FTP_PASS
}
$renamed = Register-ObjectEvent $watcher "Renamed" -Action {
    Sync-Files -localPath $LOCAL_DIR -remotePath $REMOTE_DIR -username $FTP_USER -password $FTP_PASS
}

Write-Host "$(Get-Date -Format 'HH:mm:ss') - Watching for changes in $LOCAL_DIR"
Write-Host "Press Ctrl+C to stop watching..."

try {
    while ($true) { Start-Sleep -Seconds 1 }
}
finally {
    # Clean up event handlers
    Unregister-Event -SourceIdentifier $changed.Name
    Unregister-Event -SourceIdentifier $created.Name
    Unregister-Event -SourceIdentifier $deleted.Name
    Unregister-Event -SourceIdentifier $renamed.Name
}