$ErrorActionPreference = "Stop"

$Repo = "https://github.com/formalParrot/factory42-rpc.git"
$AppName = "factory42"
$AppDir = Join-Path $HOME "factory42-rpc"

Write-Host "======================================"
Write-Host " Factory 42 Rich Presence Installer"
Write-Host "======================================"
Write-Host ""

# -----------------------------
# Check Git
# -----------------------------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Git is not installed."
    Write-Host "Install Git and run this installer again."
    exit 1
}

Write-Host "[+] Git: $(git --version)"

# -----------------------------
# Check Node
# -----------------------------

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js is not installed."
    Write-Host "Install Node.js 18+ and run this installer again."
    exit 1
}

Write-Host "[+] Node.js: $(node --version)"

# -----------------------------
# Check npm
# -----------------------------

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "[!] npm is not installed."
    exit 1
}

Write-Host "[+] npm: $(npm --version)"

# -----------------------------
# Clone repository
# -----------------------------

if (Test-Path (Join-Path $AppDir ".git")) {
    Write-Host ""
    Write-Host "[*] Repository already exists."
    Write-Host "[*] Updating repository..."

    Set-Location $AppDir
    git pull --ff-only
}
else {
    Write-Host ""
    Write-Host "[*] Cloning repository..."

    git clone $Repo $AppDir
    Set-Location $AppDir
}

# -----------------------------
# Install dependencies
# -----------------------------

Write-Host ""
Write-Host "[*] Installing npm dependencies..."

npm install

# -----------------------------
# Ask for token
# -----------------------------

Write-Host ""
Write-Host "======================================"
Write-Host " Factory 42 API Token"
Write-Host "======================================"
Write-Host ""

$SecureToken = Read-Host "API token" -AsSecureString

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

# -----------------------------
# Install PM2
# -----------------------------

Write-Host ""
Write-Host "[*] Checking PM2..."

if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host "[+] PM2 already installed."
}
else {
    Write-Host "[*] Installing PM2..."
    npm install -g pm2
}

# Refresh PATH from npm's global prefix if necessary
$NpmPrefix = npm prefix -g
$NpmBin = Join-Path $NpmPrefix

if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    $env:Path = "$NpmBin;$env:Path"
}

if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    Write-Host "[!] PM2 was installed but could not be found in PATH."
    Write-Host "Restart PowerShell and try again."
    exit 1
}

Write-Host "[+] PM2: $(pm2 -v)"

# -----------------------------
# Remove old process
# -----------------------------

if (pm2 describe $AppName 2>$null) {
    Write-Host "[*] Removing existing process..."
    pm2 delete $AppName
}

# -----------------------------
# Start app
# -----------------------------

Write-Host ""
Write-Host "[*] Starting Factory 42 Rich Presence..."

Set-Location $AppDir

pm2 start index.js --name $AppName

# -----------------------------
# Save PM2 state
# -----------------------------

Write-Host ""
Write-Host "[*] Saving PM2 process list..."

pm2 save

# -----------------------------
# Windows startup
# -----------------------------

Write-Host ""
Write-Host "======================================"
Write-Host " Windows startup"
Write-Host "======================================"
Write-Host ""

Write-Host "[*] Configuring startup..."

$StartupDir = [Environment]::GetFolderPath("Startup")
$StartupScript = Join-Path $StartupDir "factory42-pm2.cmd"

$Pm2Command = (Get-Command pm2).Source

@"
@echo off
cd /d "$AppDir"
"$Pm2Command" resurrect
"@ | Set-Content -Path $StartupScript -Encoding ASCII

Write-Host "[+] Startup entry created:"
Write-Host "    $StartupScript"

# -----------------------------
# Final status
# -----------------------------

Write-Host ""
Write-Host "======================================"
Write-Host " Installation complete"
Write-Host "======================================"
Write-Host ""

pm2 status

Write-Host ""
Write-Host "Application directory:"
Write-Host "  $AppDir"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  pm2 status"
Write-Host "  pm2 logs $AppName"
Write-Host "  pm2 restart $AppName"
Write-Host "  pm2 stop $AppName"
