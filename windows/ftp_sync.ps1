# FTP Sync Script for Windows
# Requires WinSCP (Install via: winget install WinSCP or download from winscp.net)

# Check if WinSCP is installed
if (!(Test-Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll")) {
    Write-Host "WinSCP is not installed. Please download it from https://winscp.net/eng/download.php"
    exit 1
}

# Import required modules
Add-Type -Path "${env:ProgramFiles(x86)}\WinSCP\WinSCPnet.dll"

# Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321
$SCRIPTS_DIR = "$env:USERPROFILE\Development\scripts"
$CONFIG_FILE = "$SCRIPTS_DIR\ftp-sync-config.xml"
$LOG_FILE = "$SCRIPTS_DIR\ftp-sync.log"

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $SCRIPTS_DIR | Out-Null

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Add-Content -Path $LOG_FILE
    Write-Host "$timestamp - $Message"
}

function Initialize-Config {
    if (!(Test-Path $CONFIG_FILE)) {
        Write-Host "First-time setup. Please enter your credentials:"
        $username = Read-Host "FTP Username"
        $password = Read-Host "FTP Password" -AsSecureString
        $localPath = Read-Host "Local directory to sync (e.g., C:\Projects\WebDev)"
        $remotePath = Read-Host "Remote directory path (e.g., /public_html)"

        # Convert SecureString to encrypted string
        $encryptedPassword = ConvertFrom-SecureString $password

        # Create configuration object
        $config = @{
            Username = $username
            Password = $encryptedPassword
            LocalPath = $localPath
            RemotePath = $remotePath
        }

        # Save configuration
        $config | Export-Clixml -Path $CONFIG_FILE
        Write-Log "Configuration created successfully"
    }
    return Import-Clixml -Path $CONFIG_FILE
}

function Start-FtpSync {
    param($Config)

    try {
        # Create WinSCP session options
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
        $sessionOptions.HostName = $FTP_HOST
        $sessionOptions.PortNumber = $FTP_PORT
        $sessionOptions.Username = $Config.Username
        $sessionOptions.Password = [System.Net.NetworkCredential]::new("", 
            (ConvertTo-SecureString $Config.Password)).Password
        $sessionOptions.FtpSecure = [WinSCP.FtpSecure]::Explicit

        # Create WinSCP session
        $session = New-Object WinSCP.Session
        
        try {
            $session.Open($sessionOptions)
            Write-Log "Connected to FTP server"

            # Create synchronization options
            $syncOptions = New-Object WinSCP.SynchronizationOptions
            $syncOptions.Mirror = $true
            $syncOptions.Criteria = [WinSCP.SynchronizationCriteria]::Time

            # Perform initial sync
            $result = $session.SynchronizeDirectories($syncOptions, $Config.LocalPath, 
                $Config.RemotePath)
            Write-Log "Initial sync completed. Success: $($result.IsSuccess)"
        }
        finally {
            $session.Dispose()
        }

        # Start file system watcher
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $Config.LocalPath
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents = $true

        # Define events
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $changetype = $Event.SourceEventArgs.ChangeType
            Write-Log "Change detected: $changetype - $path"

            # Create new session and sync
            $session = New-Object WinSCP.Session
            try {
                $session.Open($sessionOptions)
                $result = $session.SynchronizeDirectories($syncOptions, $Config.LocalPath, 
                    $Config.RemotePath)
                Write-Log "Sync completed after $changetype. Success: $($result.IsSuccess)"
            }
            catch {
                Write-Log "Error during sync: $_"
            }
            finally {
                $session.Dispose()
            }
        }

        # Register events
        Register-ObjectEvent $watcher "Created" -Action $action
        Register-ObjectEvent $watcher "Changed" -Action $action
        Register-ObjectEvent $watcher "Deleted" -Action $action
        Register-ObjectEvent $watcher "Renamed" -Action $action

        Write-Log "File watcher started. Monitoring for changes..."
        
        # Keep script running
        while ($true) { Start-Sleep -Seconds 1 }
    }
    catch {
        Write-Log "Error: $_"
    }
}

# Main execution
try {
    $config = Initialize-Config
    Start-FtpSync -Config $config
}
catch {
    Write-Log "Fatal error: $_"
}