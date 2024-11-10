# Ashesi Server Constants
$FTP_HOST = "169.239.251.102"
$FTP_PORT = 321

# Path to the configuration file within Development/scripts
$CONFIG_DIR = "$HOME\Development\scripts"
$CONFIG_FILE = "$CONFIG_DIR\sync_config.conf"

# Check if required tools are installed
if (-not (Get-Command "WinSCP.com" -ErrorAction SilentlyContinue)) {
    Write-Host "WinSCP is not installed. Please install it from 'https://winscp.net/eng/download.php'."
    exit 1
}

# Ensure the directory exists
if (-not (Test-Path -Path $CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CONFIG_DIR
}

# Function to read configuration
function Read-Config {
    if (Test-Path $CONFIG_FILE) {
        $config = Get-Content $CONFIG_FILE | ForEach-Object {
            $key, $value = $_ -split '='
            $key.Trim(), $value.Trim().Trim('"')
        }
        return @($config)
    } else {
        Write-Host "Configuration file not found! Let's create one."
        exit 1
    }
}

# Function to sync files
function Sync-Files {
    $config = Read-Config
    $FTP_USER = $config[0][1]
    $FTP_PASS = $config[1][1]
    $LOCAL_DIR = $config[2][1]
    $REMOTE_DIR = $config[3][1]

    # Sync command using WinSCP
    & "C:\Program Files (x86)\WinSCP\WinSCP.com" `
    /command `
    "open ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}:${FTP_PORT}" `
    "put -r $LOCAL_DIR $REMOTE_DIR" `
    "exit"
}

# Initial run to gather user input for configuration
if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "Initial setup: Please enter the following details."
    $FTP_USER = Read-Host "Ashesi Username"
    $FTP_PASS = Read-Host "FTP Password (will be stored securely)" -AsSecureString
    $LOCAL_DIR = Read-Host "Local Directory Path"
    $REMOTE_DIR = Read-Host "Remote Directory Path"

    # Save configuration securely
    $FTP_PASS = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($FTP_PASS)
    $FTP_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto($FTP_PASS)

    $configContent = @"
FTP_USER="$FTP_USER"
FTP_PASS="$FTP_PASS"
LOCAL_DIR="$LOCAL_DIR"
REMOTE_DIR="$REMOTE_DIR"
"@
    Set-Content -Path $CONFIG_FILE -Value $configContent
    Write-Host "Configuration saved successfully."
}

# Start syncing files
Sync-Files