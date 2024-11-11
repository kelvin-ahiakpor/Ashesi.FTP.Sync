# Load WinSCP .NET assembly
Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

# Define constants
$LOG_FILE = "$env:USERPROFILE\Development\scripts\ftp_sync_log.txt"
$CONFIG_FILE = "$env:USERPROFILE\Development\scripts\ftp_sync_config.json"

# Function to write log messages
function Write-Log {
    param (
        [string]$Message
    )
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$Timestamp - $Message" | Out-File -FilePath $LOG_FILE -Append
}

# Function to read configuration
function Get-Config {
    if (Test-Path $CONFIG_FILE) {
        $Config = Get-Content $CONFIG_FILE | ConvertFrom-Json
        return $Config
    } else {
        return $null
    }
}

# Function to save configuration
function Set-Config {
    param (
        [string]$FTPHost,
        [int]$FTPPort,
        [string]$FTPUsername,
        [SecureString]$FTPPassword,
        [string]$LocalPath,
        [string]$RemotePath
    )
    $Config = @{
        FTPHost = $FTPHost
        FTPPort = $FTPPort
        FTPUsername = $FTPUsername
        FTPPassword = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($FTPPassword))
        LocalDirectory = $LocalPath
        RemoteDirectory = $RemotePath
    }
    $Config | ConvertTo-Json | Set-Content -Path $CONFIG_FILE
}

# Function to sync files
function Sync-Files {
    param (
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$FTPHost,
        [int]$FTPPort,
        [string]$FTPUsername,
        [SecureString]$FTPPassword
    )
    
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::Ftp
        HostName = $FTPHost
        PortNumber = $FTPPort
        UserName = $FTPUsername
        Password = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($FTPPassword))
        FtpSecure = [WinSCP.FtpSecure]::None
    }

    $session = New-Object WinSCP.Session
    try {
        # Connect to FTP server
        $session.Open($sessionOptions)

        # Synchronize files
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Auto
        
        $transferOperationResult = $session.SynchronizeDirectories(
            [WinSCP.SynchronizationMode]::Local, 
            $LocalPath, 
            $RemotePath, 
            $False, 
            $transferOptions
        )
        
        # Check for errors
        if ($transferOperationResult.Failures -gt 0) {
            Write-Log "Transfer completed with errors."
        } else {
            Write-Log "Transfer completed successfully."
        }
    } catch {
        Write-Log "Error: $_"
    } finally {
        $session.Dispose()
    }
}

# Check if configuration file exists
$config = Get-Config

if (-not $config) {
    # Initial setup: prompt for FTP credentials
    $FTPHost = Read-Host "Enter FTP Host"
    $FTPPort = Read-Host "Enter FTP Port (default 21)"
    $FTPPort = if ($FTPPort) { [int]$FTPPort } else { 21 }
    $FTPUsername = Read-Host "Enter FTP Username"
    $FTPPassword = Read-Host "Enter FTP Password" -AsSecureString
    $LocalDirectory = Read-Host "Enter Local Directory Path"
    $RemoteDirectory = Read-Host "Enter Remote Directory Path"

    # Save configuration
    Set-Config -FTPHost $FTPHost -FTPPort $FTPPort -FTPUsername $FTPUsername -FTPPassword $FTPPassword -LocalPath $LocalDirectory -RemotePath $RemoteDirectory
    Write-Log "Configuration saved."
} else {
    # Use existing configuration
    $FTPHost = $config.FTPHost
    $FTPPort = $config.FTPPort
    $FTPUsername = $config.FTPUsername
    $FTPPassword = $config.FTPPassword
    $LocalDirectory = $config.LocalDirectory
    $RemoteDirectory = $config.RemoteDirectory
}

# Monitor the local directory for changes
$FileSystemWatcher = New-Object System.IO.FileSystemWatcher
$FileSystemWatcher.Path = $LocalDirectory
$FileSystemWatcher.IncludeSubdirectories = $true
$FileSystemWatcher.EnableRaisingEvents = $true

# Event handler for changed files
$FileSystemWatcher.Changed += {
    Write-Log "File changed: $($_.FullPath)"
    Sync-Files -LocalPath $LocalDirectory -RemotePath $RemoteDirectory -FTPHost $FTPHost -FTPPort $FTPPort -FTPUsername $FTPUsername -FTPPassword $FTPPassword
}

# Event handler for created files
$FileSystemWatcher.Created += {
    Write-Log "File created: $($_.FullPath)"
    Sync-Files -LocalPath $LocalDirectory -RemotePath $RemoteDirectory -FTPHost $FTPHost -FTPPort $FTPPort -FTPUsername $FTPUsername -FTPPassword $FTPPassword
}

# Event handler for deleted files
$FileSystemWatcher.Deleted += {
    Write-Log "File deleted: $($_.FullPath)"
    Sync-Files -LocalPath $LocalDirectory -RemotePath $RemoteDirectory -FTPHost $FTPHost -FTPPort $FTPPort -FTPUsername $FTPUsername -FTPPassword $FTPPassword
}

# Keep the script running
Write-Log "Monitoring started for $LocalDirectory."
while ($true) { Start-Sleep -Seconds 1 }