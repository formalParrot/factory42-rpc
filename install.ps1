$ErrorActionPreference = "Stop"

$Repo = "https://github.com/formalParrot/factory42-rpc.git"
$AppName = "factory42"
$AppDir = Join-Path $HOME "factory42-rpc"

Write-Host ""
Write-Host "=========================================="
Write-Host " Factory 42 Rich Presence Installer"
Write-Host "=========================================="
Write-Host ""

# ==========================================
# Check winget
# ==========================================

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[!] winget is not available."
    Write-Host ""
    Write-Host "Windows App Installer / winget is required."
    Write-Host "Install it through Microsoft Store, then run this script again."
    exit 1
}

Write-Host "[+] winget available."

# ==========================================
# Check / install Git
# ==========================================

Write-Host ""
Write-Host "[*] Checking Git..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {

    Write-Host "[!] Git is not installed."
    Write-Host "[*] Installing Git..."

    winget install Git.Git `
        --accept-source-agreements `
        --accept-package-agreements `
        --silent

    Write-Host "[*] Refreshing PATH..."

    $env:Path =
        [Environment]::GetEnvironmentVariable("Path", "Machine") +
        ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {

    $GitPath = "C:\Program Files\Git\cmd"

    if (Test-Path "$GitPath\git.exe") {
        $env:Path = "$GitPath;$env:Path"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Git installation failed or PATH was not refreshed."
    Write-Host "Restart PowerShell and run the installer again."
    exit 1
}

Write-Host "[+] Git: $(git --version)"

# ==========================================
# Check / install Node.js
# ==========================================

Write-Host ""
Write-Host "[*] Checking Node.js..."

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {

    Write-Host "[!] Node.js is not installed."
    Write-Host "[*] Installing Node.js LTS..."

    winget install OpenJS.NodeJS.LTS `
        --accept-source-agreements `
        --accept-package-agreements `
        --silent

    Write-Host "[*] Refreshing PATH..."

    $env:Path =
        [Environment]::GetEnvironmentVariable("Path", "Machine") +
        ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {

    $NodePath = "C:\Program Files\nodejs"

    if (Test-Path "$NodePath\node.exe") {
        $env:Path = "$NodePath;$env:Path"
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js installation failed."
    Write-Host "Restart PowerShell and run the installer again."
    exit 1
}

Write-Host "[+] Node.js: $(node --version)"

# ==========================================
# Check npm
# ==========================================

Write-Host ""
Write-Host "[*] Checking npm..."

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {

    $NodePath = "C:\Program Files\nodejs"

    if (Test-Path "$NodePath\npm.cmd") {
        $env:Path = "$NodePath;$env:Path"
    }
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "[!] npm could not be found."
    exit 1
}

Write-Host "[+] npm: $(npm --version)"

# ==========================================
# Clone / update repository
# ==========================================

Write-Host ""
Write-Host "[*] Preparing repository..."

if (Test-Path (Join-Path $AppDir ".git")) {

    Write-Host "[+] Repository already exists."

    Set-Location $AppDir

    Write-Host "[*] Pulling latest changes..."
    git pull --ff-only

}
elseif (Test-Path $AppDir) {

    Write-Host "[!] $AppDir already exists but is not a Git repository."
    Write-Host "[!] Refusing to overwrite it."
    exit 1

}
else {

    Write-Host "[*] Cloning repository..."

    git clone $Repo $AppDir

    Set-Location $AppDir
}

# ==========================================
# Install dependencies
# ==========================================

Write-Host ""
Write-Host "[*] Installing npm dependencies..."

npm install

Write-Host "[+] Dependencies installed."

# ==========================================
# Ask for token
# ==========================================

Write-Host ""
Write-Host "=========================================="
Write-Host " Factory 42 API Token"
Write-Host "=========================================="
Write-Host ""

$SecureToken = Read-Host "FACTORY_42_TOKEN" -AsSecureString

$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken)

try {
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "[!] Token cannot be empty."
    exit 1
}

@"
FACTORY_42_TOKEN='$Token'
"@ | Set-Content -Path ".env" -Encoding UTF8

Write-Host "[+] .env created."

# ==========================================
# Install PM2
# ==========================================

Write-Host ""
Write-Host "[*] Checking PM2..."

if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {

    Write-Host "[!] PM2 is not installed."
    Write-Host "[*] Installing PM2 globally..."

    npm install -g pm2

    $NpmPrefix = npm prefix -g

    $env:Path = "$NpmPrefix;$env:Path"
}

if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    Write-Host "[!] PM2 was installed but could not be found."
    Write-Host "Restart PowerShell and run the installer again."
    exit 1
}

Write-Host "[+] PM2: $(pm2 --version)"

# ==========================================
# Remove existing process
# ==========================================

Write-Host ""
Write-Host "[*] Checking existing PM2 process..."

$ExistingProcess = pm2 describe $AppName 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[*] Existing process found."
    pm2 delete $AppName
}

# ==========================================
# Start application
# ==========================================

Write-Host ""
Write-Host "[*] Starting Factory 42 Rich Presence..."

Set-Location $AppDir

pm2 start index.js --name factory42

# ==========================================
# Save PM2 process list
# ==========================================

Write-Host ""
Write-Host "[*] Saving PM2 process list..."

pm2 save

# ==========================================
# Configure Windows startup
# ==========================================

Write-Host ""
Write-Host "=========================================="
Write-Host " Windows Startup"
Write-Host "=========================================="
Write-Host ""

$StartupDir = [Environment]::GetFolderPath("Startup")
$StartupFile = Join-Path $StartupDir "factory42-pm2.cmd"

$Pm2Command = (Get-Command pm2).Source

@"
@echo off
cd /d "$AppDir"
"$Pm2Command" resurrect
"@ | Set-Content -Path $StartupFile -Encoding ASCII

Write-Host "[+] Windows startup entry created."
Write-Host "    $StartupFile"

# ==========================================
# Verify
# ==========================================

Write-Host ""
Write-Host "=========================================="
Write-Host " Installation complete"
Write-Host "=========================================="
Write-Host ""

pm2 status

Write-Host ""
Write-Host "Application:"
Write-Host "  $AppDir"
Write-Host ""
Write-Host "PM2 name:"
Write-Host "  $AppName"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  pm2 status"
Write-Host "  pm2 logs factory42"
Write-Host "  pm2 restart factory42"
Write-Host "  pm2 stop factory42"
Write-Host ""
