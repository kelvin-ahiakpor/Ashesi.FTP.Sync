# Requires: WinSCP .NET Assembly (https://winscp.net/eng/download.php)

# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Constants
$SCRIPTS_DIR = "$env:USERPROFILE\Development\scripts"
$ConfigFilePath = "$SCRIPTS_DIR\ftp_config.json"
$LogFilePath = "$SCRIPTS_DIR\ftp_sync.log"
$WinSCPPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

# Ensure the WinSCP .NET Assembly is loaded
if (!(Test-Path $WinSCPPath)) {
    Write-Error "WinSCP .NET assembly not found at $WinSCPPath. Please install it."
    exit 1
}
Add-Type -Path $WinSCPPath

# Function to encrypt password
Function Protect-Password($Password) {
    [Convert]::ToBase64String([System.Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($Password), $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser))
}

# Function to decrypt password
Function Unprotect-Password($EncryptedPassword) {
    [Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($EncryptedPassword), $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser))
}

# Load configuration or set up if missing
if (!(Test-Path $ConfigFilePath)) {
    Write-Host "Configuration not found. Running initial setup..."
    $Username = Read-Host "Enter FTP Username"
    $Password = Read-Host "Enter FTP Password"
    $EncryptedPassword = Protect-Password $Password
    $LocalDir = Read-Host "Enter Local Directory Path"
    $RemoteDir = Read-Host "Enter Remote Directory Path"

    # Save to config
    $Config = @{
        Username = $Username
        Password = $EncryptedPassword
        LocalDir = $LocalDir
        RemoteDir = $RemoteDir
    }
    $Config | ConvertTo-Json | Out-File $ConfigFilePath -Force
    Write-Host "Configuration saved to $ConfigFilePath."
} else {
    Write-Host "Loading configuration from $ConfigFilePath..."
    $Config = Get-Content $ConfigFilePath | ConvertFrom-Json
    $Username = $Config.Username
    $Password = Unprotect-Password $Config.Password
    $LocalDir = $Config.LocalDir
    $RemoteDir = $Config.RemoteDir
}

# Check if Local Directory exists
if (!(Test-Path $LocalDir)) {
    Write-Error "Local directory $LocalDir does not exist."
    exit 1
}

# Watcher to monitor directory changes
$Watcher = New-Object System.IO.FileSystemWatcher
$Watcher.Path = $LocalDir
$Watcher.IncludeSubdirectories = $true
$Watcher.EnableRaisingEvents = $true

# Debounce handler
$SyncQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$Timer = New-Object System.Timers.Timer
$Timer.Interval = 1000
$Timer.AutoReset = $false
$Timer.Add_Elapsed({
    Sync-Files
})

# Log sync activity
Function Write-Activity($Message) {
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFilePath -Value "[$Timestamp] $Message"
}

# Function to sync files using WinSCP
Function Sync-Files {
    while ($SyncQueue.TryDequeue([ref]$FilePath)) {
        try {
            $SessionOptions = New-Object WinSCP.SessionOptions -Property @{
                Protocol = [WinSCP.Protocol]::Ftp
                HostName = $FTP_HOST
                PortNumber = $FTP_PORT
                UserName = $Username
                Password = $Password
            }

            $Session = New-Object WinSCP.Session
            $Session.Open($SessionOptions)

            $Session.PutFiles($LocalDir, $RemoteDir, $true).Check()
            Write-Activity "Synced file: $FilePath"
        } catch {
            Write-Activity "Error syncing file: $_"
        } finally {
            if ($Session) { $Session.Dispose() }
        }
    }
}

# Event Handlers
$OnChange = {
    if (!$Timer.Enabled) { $Timer.Start() }
    $SyncQueue.Enqueue($EventArgs.FullPath)
}

$Watcher.Changed += $OnChange
$Watcher.Created += $OnChange
$Watcher.Deleted += $OnChange
$Watcher.Renamed += $OnChange

Write-Host "Watching $LocalDir for changes. Press Ctrl+C to exit."
Write-Activity "Started watching $LocalDir for changes."

# Keep script running
try {
    while ($true) { Start-Sleep -Seconds 1 }
} catch {
    $Watcher.Dispose()
    $Timer.Dispose()
    Write-Activity "Stopped watching $LocalDir."
    Write-Host "Exiting..."
}
