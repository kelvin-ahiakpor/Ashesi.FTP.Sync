# FTP Sync Script for Windows
# Requires WinSCP (Install via: winget install WinSCP or download from winscp.net)

# Check if WinSCP is installed
if (!(Test-Path "${env:ProgramFiles(x86)}\WinSCP\WinSCPnet.dll")) {
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

function Test-FtpConnection {
    param($SessionOptions)
    $testSession = New-Object WinSCP.Session
    try {
        Write-Host "Testing FTP connection..."
        $testSession.Open($SessionOptions)
        return $true
    }
    catch {
        Write-Host "Connection test failed: $_"
        return $false
    }
    finally {
        $testSession.Dispose()
    }
}

function Initialize-Config {
    do {
        if (!(Test-Path $CONFIG_FILE)) {
            Write-Host "First-time setup. Please enter your credentials:"
            $username = Read-Host "FTP Username"
            $password = Read-Host "FTP Password" -AsSecureString
            $localPath = Read-Host "Local directory to sync (e.g., C:\Projects\WebDev)"
            $remotePath = Read-Host "Remote directory path (e.g., /public_html)"

            # Convert SecureString to encrypted string
            $encryptedPassword = ConvertFrom-SecureString $password

            # Test connection before saving
            $sessionOptions = New-Object WinSCP.SessionOptions
            $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
            $sessionOptions.HostName = $FTP_HOST
            $sessionOptions.PortNumber = $FTP_PORT
            $sessionOptions.Username = $username
            $sessionOptions.Password = [System.Net.NetworkCredential]::new("", 
                (ConvertTo-SecureString $encryptedPassword)).Password
            $sessionOptions.TimeoutInMilliseconds = 10000

            if (Test-FtpConnection $sessionOptions) {
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
                return $config
            }
            else {
                Write-Host "Would you like to try again? (Y/N)"
                $retry = Read-Host
                if ($retry -ne "Y" -and $retry -ne "y") {
                    exit 1
                }
            }
        }
        else {
            return Import-Clixml -Path $CONFIG_FILE
        }
    } while ($true)
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
        $sessionOptions.TimeoutInMilliseconds = 10000

        # Create WinSCP session
        $session = New-Object WinSCP.Session
        
        try {
            Write-Host "Connecting to FTP server..."
            $session.Open($sessionOptions)
            Write-Log "Connected to FTP server"

            # Perform initial sync using TransferOptions instead of SynchronizationOptions
            $transferOptions = New-Object WinSCP.TransferOptions
            $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
            
            # Upload all local files
            $localFiles = Get-ChildItem -Path $Config.LocalPath -Recurse
            foreach ($file in $localFiles) {
                if (!$file.PSIsContainer) {
                    $relativePath = $file.FullName.Substring($Config.LocalPath.Length)
                    $remotePath = Join-Path $Config.RemotePath $relativePath
                    $session.PutFiles($file.FullName, $remotePath, $false, $transferOptions)
                    Write-Log "Uploaded: $($file.Name)"
                }
            }
            
            Write-Log "Initial sync completed successfully"
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
                $transferOptions = New-Object WinSCP.TransferOptions
                $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

                if ($changetype -eq 'Changed' -or $changetype -eq 'Created') {
                    $relativePath = $path.Substring($Config.LocalPath.Length)
                    $remotePath = Join-Path $Config.RemotePath $relativePath
                    $session.PutFiles($path, $remotePath, $false, $transferOptions)
                    Write-Log "Uploaded: $path"
                }
                elseif ($changetype -eq 'Deleted') {
                    $relativePath = $path.Substring($Config.LocalPath.Length)
                    $remotePath = Join-Path $Config.RemotePath $relativePath
                    $session.RemoveFiles($remotePath)
                    Write-Log "Deleted: $remotePath"
                }
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