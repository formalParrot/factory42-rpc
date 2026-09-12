$ErrorActionPreference = "Stop"

$Repo = "https://github.com/formalParrot/factory42-rpc.git"
$AppName = "factory42"
$AppDir = Join-Path $env:USERPROFILE "factory42-rpc"

Write-Host ""
Write-Host "========================================="
Write-Host " Factory 42 Discord Rich Presence"
Write-Host " Windows Installer"
Write-Host "========================================="
Write-Host ""

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Require-Command {
    param (
        [string]$Command,
        [string]$Name
    )

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Name was not found in PATH."
    }
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = "$machinePath;$userPath"
}

# ------------------------------------------------------------
# Check winget
# ------------------------------------------------------------

Write-Host "[1/8] Checking winget..."

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw "winget is not installed. Install App Installer from Microsoft Store first."
}

Write-Host "winget found."

# ------------------------------------------------------------
# Install Git
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2/8] Checking Git..."

if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Git is missing. Installing Git..."

    winget install `
        --id Git.Git `
        --exact `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent

    Refresh-Path
}

Require-Command "git.exe" "Git"

Write-Host "Git: $(git --version)"

# ------------------------------------------------------------
# Install Node.js
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3/8] Checking Node.js..."

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js is missing. Installing Node.js LTS..."

    winget install `
        --id OpenJS.NodeJS.LTS `
        --exact `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent

    Refresh-Path
}

Require-Command "node.exe" "Node.js"
Require-Command "npm.cmd" "npm"

Write-Host "Node: $(node --version)"
Write-Host "npm:  $(npm --version)"

# ------------------------------------------------------------
# Clone / update repository
# ------------------------------------------------------------

Write-Host ""
Write-Host "[4/8] Setting up repository..."

if (Test-Path $AppDir) {

    Write-Host "Repository directory already exists:"
    Write-Host "  $AppDir"

    if (-not (Test-Path (Join-Path $AppDir ".git"))) {
        throw "$AppDir exists but is not a Git repository."
    }

    Push-Location $AppDir

    Write-Host "Updating repository..."

    git fetch origin
    git reset --hard origin/main

    Pop-Location

} else {

    Write-Host "Cloning repository..."
    Write-Host "  $Repo"
    Write-Host "  -> $AppDir"

    git clone $Repo $AppDir
}

# ------------------------------------------------------------
# Verify repository
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5/8] Verifying repository..."

if (-not (Test-Path $AppDir)) {
    throw "Repository directory was not created: $AppDir"
}

$IndexFile = Join-Path $AppDir "index.js"

if (-not (Test-Path $IndexFile)) {
    Write-Host ""
    Write-Host "Repository contents:"
    Get-ChildItem $AppDir | Format-Table Name, Length
    Write-Host ""

    throw "index.js was not found in $AppDir"
}

Write-Host "Repository OK."
Write-Host "index.js found."

# ------------------------------------------------------------
# Install npm dependencies
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6/8] Installing npm dependencies..."

Push-Location $AppDir

if (-not (Test-Path (Join-Path $AppDir "package.json"))) {
    Pop-Location
    throw "package.json was not found."
}

npm install

if ($LASTEXITCODE -ne 0) {
    Pop-Location
    throw "npm install failed."
}

Pop-Location

Write-Host "npm install completed."

# ------------------------------------------------------------
# Ask for token
# ------------------------------------------------------------

Write-Host ""
Write-Host "[7/8] Configuring Factory 42 token..."
Write-Host ""

$SecureToken = Read-Host "Enter FACTORY_42_TOKEN" -AsSecureString

$TokenPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
    $SecureToken
)

try {
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($TokenPtr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($TokenPtr)
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "FACTORY_42_TOKEN cannot be empty."
}

$EnvFile = Join-Path $AppDir ".env"

"FACTORY_42_TOKEN='$Token'" | Set-Content `
    -Path $EnvFile `
    -Encoding UTF8 `
    -NoNewline

Write-Host ".env created."

# ------------------------------------------------------------
# Install PM2
# ------------------------------------------------------------

Write-Host ""
Write-Host "[8/8] Installing and configuring PM2..."

if (-not (Get-Command pm2.cmd -ErrorAction SilentlyContinue)) {

    Write-Host "Installing PM2 globally..."

    npm install -g pm2

    if ($LASTEXITCODE -ne 0) {
        throw "PM2 installation failed."
    }

    Refresh-Path
}

Require-Command "pm2.cmd" "PM2"

Write-Host "PM2: $(pm2 --version)"

# ------------------------------------------------------------
# Start application
# ------------------------------------------------------------

Write-Host ""
Write-Host "Starting Factory 42 RPC..."

Push-Location $AppDir

# Remove an old instance if one exists.
pm2 delete $AppName 2>$null

# Start EXACTLY the requested application.
pm2 start index.js --name factory42

if ($LASTEXITCODE -ne 0) {
    Pop-Location
    throw "PM2 failed to start index.js."
}

Pop-Location

# Save PM2 process list
Write-Host ""
Write-Host "Saving PM2 process list..."

pm2 save

if ($LASTEXITCODE -ne 0) {
    throw "pm2 save failed."
}

# ------------------------------------------------------------
# Windows startup
# ------------------------------------------------------------

Write-Host ""
Write-Host "Configuring Windows startup..."

$StartupDir = Join-Path `
    $env:APPDATA `
    "Microsoft\Windows\Start Menu\Programs\Startup"

if (-not (Test-Path $StartupDir)) {
    New-Item -ItemType Directory -Path $StartupDir -Force | Out-Null
}

$StartupFile = Join-Path $StartupDir "factory42-pm2.cmd"

@"
@echo off
set "PATH=C:\Program Files\nodejs;%APPDATA%\npm;%PATH%"
cd /d "$AppDir"
call pm2 resurrect
"@ | Set-Content `
    -Path $StartupFile `
    -Encoding ASCII

Write-Host "Startup file created:"
Write-Host "  $StartupFile"

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================="
Write-Host " Verification"
Write-Host "========================================="
Write-Host ""

Write-Host "Application directory:"
Write-Host "  $AppDir"

Write-Host ""
Write-Host "index.js:"
Write-Host "  $IndexFile"

Write-Host ""
Write-Host "PM2 status:"
pm2 status

Write-Host ""
Write-Host "Recent application logs:"
pm2 logs $AppName --lines 20 --nostream

Write-Host ""
Write-Host "========================================="
Write-Host " Installation complete"
Write-Host "========================================="
Write-Host ""

Write-Host "Factory 42 RPC is running under PM2."
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  pm2 status"
Write-Host "  pm2 logs factory42"
Write-Host "  pm2 restart factory42"
Write-Host "  pm2 stop factory42"
Write-Host "  pm2 delete factory42"
Write-Host ""
