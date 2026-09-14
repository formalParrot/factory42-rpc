@echo off
setlocal EnableDelayedExpansion

set "REPO=git@github.com:formalParrot/factory42-rpc.git"
set "APP_NAME=factory42"
set "APP_DIR=%USERPROFILE%\factory42-rpc"

echo.
echo ==========================================
echo  Factory 42 Rich Presence Installer
echo ==========================================
echo.

echo [+] Operating system: Windows

:: ==========================================
:: Helper: refresh PATH for this session from registry
:: (so a newly installed tool becomes visible without reopening cmd)
:: ==========================================
call :refreshpath

:: ==========================================
:: Check for winget (used to install Git / Node if missing)
:: ==========================================
where winget >nul 2>&1
if errorlevel 1 (
    set "HAVE_WINGET=0"
) else (
    set "HAVE_WINGET=1"
)

:: ==========================================
:: Install Git
:: ==========================================
where git >nul 2>&1
if errorlevel 1 (
    echo [!] Git is not installed.

    if "%HAVE_WINGET%"=="1" (
        echo [*] Installing Git via winget...
        winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
        call :refreshpath
    ) else (
        echo [!] winget is not available on this system.
        echo [!] Install Git manually from https://git-scm.com/download/win
        echo [!] then run this script again.
        exit /b 1
    )
)

where git >nul 2>&1
if errorlevel 1 (
    echo [!] Git is still unavailable. Close this window, open a new
    echo     Command Prompt so PATH updates take effect, and re-run this script.
    exit /b 1
)

for /f "delims=" %%V in ('git --version') do set "GIT_VERSION=%%V"
echo [+] Git: %GIT_VERSION%

:: ==========================================
:: Install Node.js + npm
:: ==========================================
where node >nul 2>&1
set "NODE_MISSING=%errorlevel%"
where npm >nul 2>&1
set "NPM_MISSING=%errorlevel%"

if not "%NODE_MISSING%"=="0" (
    set "NEED_NODE=1"
) else if not "%NPM_MISSING%"=="0" (
    set "NEED_NODE=1"
) else (
    set "NEED_NODE=0"
)

if "%NEED_NODE%"=="1" (
    echo [!] Node.js/npm not found.

    if "%HAVE_WINGET%"=="1" (
        echo [*] Installing Node.js LTS via winget...
        winget install --id OpenJS.NodeJS.LTS -e --source winget --silent --accept-package-agreements --accept-source-agreements
        call :refreshpath
        set "PATH=%PATH%;%ProgramFiles%\nodejs"
    ) else (
        echo [!] winget is not available on this system.
        echo [!] Install Node.js LTS manually from https://nodejs.org/
        echo [!] then run this script again.
        exit /b 1
    )
)

where node >nul 2>&1
if errorlevel 1 (
    echo [!] Node.js installation failed, or PATH has not refreshed.
    echo     Close this window, open a new Command Prompt, and re-run this script.
    exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
    echo [!] npm installation failed, or PATH has not refreshed.
    echo     Close this window, open a new Command Prompt, and re-run this script.
    exit /b 1
)

for /f "delims=" %%V in ('node --version') do set "NODE_VERSION=%%V"
for /f "delims=" %%V in ('npm --version') do set "NPM_VERSION=%%V"
echo [+] Node.js: %NODE_VERSION%
echo [+] npm: %NPM_VERSION%

:: ==========================================
:: Clone / update repository
:: ==========================================
echo.
echo [*] Preparing repository...

if exist "%APP_DIR%\.git" (
    echo [+] Repository already exists.
    cd /d "%APP_DIR%"

    echo [*] Pulling latest changes...
    git pull --ff-only
    if errorlevel 1 (
        echo [!] git pull failed.
        exit /b 1
    )
) else (
    if exist "%APP_DIR%" (
        echo [!] %APP_DIR% already exists but is not a Git repository.
        echo [!] Refusing to overwrite it.
        exit /b 1
    )

    echo [*] Cloning repository...
    git clone "%REPO%" "%APP_DIR%"
    if errorlevel 1 (
        echo [!] git clone failed.
        exit /b 1
    )

    cd /d "%APP_DIR%"
)

:: ==========================================
:: Install dependencies
:: ==========================================
echo.
echo [*] Installing npm dependencies...

call npm install
if errorlevel 1 (
    echo [!] npm install failed.
    exit /b 1
)

echo [+] Dependencies installed.

:: ==========================================
:: Create .env
:: ==========================================
echo.
echo ==========================================
echo  Factory 42 API Token
echo ==========================================
echo.
echo Enter your Factory 42 API token.
echo The input will not be displayed.
echo.

set "FACTORY_42_TOKEN="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command ^
    "$secure = Read-Host -AsSecureString 'FACTORY_42_TOKEN'; $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure); [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)"`) do (
    set "FACTORY_42_TOKEN=%%T"
)

if "%FACTORY_42_TOKEN%"=="" (
    echo [!] Token cannot be empty.
    exit /b 1
)

(
    echo FACTORY_42_TOKEN=%FACTORY_42_TOKEN%
) > .env

:: Restrict .env to the current user only (closest equivalent to chmod 600)
icacls .env /inheritance:r >nul 2>&1
icacls .env /grant:r "%USERNAME%:F" >nul 2>&1

echo [+] .env created.

:: ==========================================
:: Install PM2
:: ==========================================
echo.
echo [*] Checking PM2...

where pm2 >nul 2>&1
if errorlevel 1 (
    echo [*] Installing PM2 globally...
    call npm install -g pm2
    call :refreshpath
)

where pm2 >nul 2>&1
if errorlevel 1 (
    echo.
    echo [!] PM2 was installed but cannot be found in PATH.
    echo.
    echo Close this window, open a new Command Prompt, and re-run this script.
    echo.
    exit /b 1
)

for /f "delims=" %%V in ('pm2 --version') do set "PM2_VERSION=%%V"
echo [+] PM2: %PM2_VERSION%

:: ==========================================
:: Remove existing PM2 process
:: ==========================================
echo.
echo [*] Checking existing PM2 process...

pm2 describe "%APP_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo [*] Removing existing %APP_NAME% process...
    pm2 delete "%APP_NAME%"
)

:: ==========================================
:: Start application
:: ==========================================
echo.
echo [*] Starting Factory 42 Rich Presence...

pm2 start index.js --name %APP_NAME%
if errorlevel 1 (
    echo [!] Failed to start the application with PM2.
    exit /b 1
)

:: ==========================================
:: Save PM2 process list
:: ==========================================
echo.
echo [*] Saving PM2 process list...

pm2 save

:: ==========================================
:: Configure startup
:: ==========================================
echo.
echo ==========================================
echo  PM2 Startup
echo ==========================================
echo.
echo [*] Configuring PM2 to start on Windows boot...
echo     (using the pm2-windows-startup package)

where pm2-startup >nul 2>&1
if errorlevel 1 (
    echo [*] Installing pm2-windows-startup...
    call npm install -g pm2-windows-startup
    call :refreshpath
)

where pm2-startup >nul 2>&1
if errorlevel 1 (
    echo.
    echo [!] pm2-startup command not found after installation.
    echo [!] Close this window, open a new Command Prompt, and run:
    echo.
    echo       pm2-startup install
    echo       pm2 save
    echo.
) else (
    pm2-startup install
    pm2 save
    echo [+] PM2 startup configured.
)

:: ==========================================
:: Verify
:: ==========================================
echo.
echo ==========================================
echo  Installation complete
echo ==========================================
echo.

pm2 status

echo.
echo Application:
echo   %APP_DIR%
echo.
echo PM2 name:
echo   %APP_NAME%
echo.
echo Useful commands:
echo   pm2 status
echo   pm2 logs factory42
echo   pm2 restart factory42
echo   pm2 stop factory42
echo.

endlocal
exit /b 0

:: ==========================================
:: Subroutine: refreshpath
:: Pulls current System + User PATH from the registry into this session,
:: so tools installed by winget/npm during this run become visible
:: without needing to open a new Command Prompt window.
:: ==========================================
:refreshpath
set "SYS_PATH="
set "USR_PATH="
for /f "tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2,*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%B"
if defined SYS_PATH if defined USR_PATH set "PATH=%SYS_PATH%;%USR_PATH%"
goto :eof
