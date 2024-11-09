# Ashesi FTP Sync Script for Windows
# Requires WinSCP to be installed

# Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Configuration paths
$CONFIG_DIR = "$HOME\Development\scripts"
$CONFIG_FILE = "$CONFIG_DIR\sync_config.conf"
$LOCK_FILE = "$env:TEMP\sync_in_progress.lock"
$WINSCP_PATH = "${env:ProgramFiles(x86)}\WinSCP\WinSCP.com"

# Ensure WinSCP is installed
if (-not (Test-Path $WINSCP_PATH)) {
    Write-Host "WinSCP is not installed. Please install it from https://winscp.net/"
    exit 1
}

# Add WinSCP .NET assembly
Add-Type -Path "${env:ProgramFiles(x86)}\WinSCP\WinSCPnet.dll"

# Ensure config directory exists
if (-not (Test-Path $CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CONFIG_DIR | Out-Null
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Created directory $CONFIG_DIR for configuration file."
}

# Function to securely store credentials
function Set-FtpCredentials {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$SecurePassword
    )
    
    $credentialPath = "$CONFIG_DIR\credentials.xml"
    $credentials = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
    $credentials | Export-Clixml -Path $credentialPath
    
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Credentials stored securely."
}

# Function to retrieve stored credentials
function Get-FtpCredentials {
    $credentialPath = "$CONFIG_DIR\credentials.xml"
    if (Test-Path $credentialPath) {
        Import-Clixml -Path $credentialPath
    }
}

# Function to sync files using WinSCP
function Sync-FtpFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LocalPath,
        
        [Parameter(Mandatory = $true)]
        [string]$RemotePath,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credentials
    )

    try {
        # Setup session options
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
        $sessionOptions.HostName = $FTP_HOST
        $sessionOptions.PortNumber = $FTP_PORT
        $sessionOptions.UserName = $Credentials.UserName
        $sessionOptions.Password = $Credentials.GetNetworkCredential().Password
        
        # Create session
        $session = New-Object WinSCP.Session
        
        try {
            # Connect
            $session.Open($sessionOptions)
            
            # Get modified files in the last second
            $recentFiles = Get-ChildItem -Path $LocalPath -Recurse -File | 
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddSeconds(-1) }
            
            foreach ($file in $recentFiles) {
                # Calculate relative path
                $relativePath = $file.FullName.Substring($LocalPath.Length + 1)
                $remoteFilePath = "$RemotePath/$($relativePath.Replace('\', '/'))"
                
                # Upload file
                $transferOptions = New-Object WinSCP.TransferOptions
                $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
                
                $transferResult = $session.PutFiles($file.FullName, $remoteFilePath, $False, $transferOptions)
                
                if ($transferResult.IsSuccess) {
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Synced file: $($file.FullName)"
                } else {
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Failed to sync: $($file.FullName)"
                }
            }
        }
        finally {
            # Disconnect, clean up
            $session.Dispose()
        }
    }
    catch {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Error: $($_.Exception.Message)"
    }
}

# Check if configuration exists
if (Test-Path $CONFIG_FILE) {
    # Load existing configuration
    $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
    $credentials = Get-FtpCredentials
}
else {
    # Prompt for configuration
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Configuration file not found. Let's create one."
    
    $username = Read-Host "Enter your Ashesi username"
    $securePassword = Read-Host "Enter your FTP password" -AsSecureString
    $localDir = Read-Host "Enter the local path to your lab/project directory (e.g., C:\Projects\Lab)"
    $remoteDir = Read-Host "Enter the remote path on the server (e.g., /public_html/RECIPE_SHARING)"
    
    # Store credentials securely
    Set-FtpCredentials -Username $username -SecurePassword $securePassword
    $credentials = Get-FtpCredentials
    
    # Save configuration
    $config = @{
        LocalDir = $localDir
        RemoteDir = $remoteDir
    }
    $config | ConvertTo-Json | Set-Content $CONFIG_FILE
    
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Configuration saved. You are ready to sync!"
}

# Initial sync
Sync-FtpFiles -LocalPath $config.LocalDir -RemoteDir $config.RemoteDir -Credentials $credentials

# Start monitoring for changes
Write-Host "$(Get-Date -Format 'HH:mm:ss') - Starting file monitoring..."

while ($true) {
    if (-not (Test-Path $LOCK_FILE)) {
        New-Item -ItemType File -Path $LOCK_FILE | Out-Null
        
        try {
            Sync-FtpFiles -LocalPath $config.LocalDir -RemoteDir $config.RemoteDir -Credentials $credentials
        }
        finally {
            Remove-Item -Path $LOCK_FILE -Force
        }
    }
    else {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Sync already in progress. Skipping..."
    }
    
    Start-Sleep -Seconds 1
}