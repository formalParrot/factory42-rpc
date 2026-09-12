#!/usr/bin/env bash

set -e

REPO="https://github.com/formalParrot/factory42-rpc.git"
APP_NAME="factory42"
APP_DIR="$HOME/factory42-rpc"

echo "======================================"
echo " Factory 42 Rich Presence Installer"
echo "======================================"
echo

# -----------------------------
# Detect OS
# -----------------------------

OS="$(uname -s)"

case "$OS" in
    Darwin)
        PLATFORM="macOS"
        ;;
    Linux)
        PLATFORM="Linux"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "[*] Detected: $PLATFORM"

# -----------------------------
# Check Git
# -----------------------------

if ! command -v git >/dev/null 2>&1; then
    echo
    echo "[!] Git is not installed."
    echo
    echo "Install Git, then run this installer again."

    if [ "$PLATFORM" = "macOS" ]; then
        echo "macOS:"
        echo "  xcode-select --install"
    elif [ "$PLATFORM" = "Linux" ]; then
        echo "Debian/Ubuntu:"
        echo "  sudo apt install git"
    fi

    exit 1
fi

echo "[+] Git: $(git --version)"

# -----------------------------
# Check Node
# -----------------------------

if ! command -v node >/dev/null 2>&1; then
    echo
    echo "[!] Node.js is not installed."
    echo
    echo "Install Node.js 18+ and run this installer again."
    exit 1
fi

NODE_VERSION="$(node -v)"
echo "[+] Node.js: $NODE_VERSION"

# -----------------------------
# Check npm
# -----------------------------

if ! command -v npm >/dev/null 2>&1; then
    echo
    echo "[!] npm is not installed."
    echo "Node.js appears to be installed incorrectly."
    exit 1
fi

echo "[+] npm: $(npm -v)"

# -----------------------------
# Clone repository
# -----------------------------

if [ -d "$APP_DIR/.git" ]; then
    echo
    echo "[*] Repository already exists."
    echo "[*] Updating repository..."

    cd "$APP_DIR"
    git pull --ff-only
else
    echo
    echo "[*] Cloning repository..."
    git clone "$REPO" "$APP_DIR"
    cd "$APP_DIR"
fi

# -----------------------------
# Install dependencies
# -----------------------------

echo
echo "[*] Installing npm dependencies..."

npm install

# -----------------------------
# Create .env
# -----------------------------

echo
echo "======================================"
echo " Factory 42 API Token"
echo "======================================"
echo
echo "Enter the FACTORY_42_TOKEN used by"
echo "the Factory 42 API."
echo

read -r -s -p "API token: " FACTORY_42_TOKEN
echo

if [ -z "$FACTORY_42_TOKEN" ]; then
    echo
    echo "[!] Token cannot be empty."
    exit 1
fi

cat > .env <<EOF
FACTORY_42_TOKEN='$FACTORY_42_TOKEN'
EOF

chmod 600 .env

echo "[+] .env created."

# -----------------------------
# Install PM2
# -----------------------------

echo
echo "[*] Checking PM2..."

if command -v pm2 >/dev/null 2>&1; then
    echo "[+] PM2 already installed."
else
    echo "[*] Installing PM2 globally..."
    npm install -g pm2
fi

# npm global bin can sometimes not be in PATH
# immediately after installation.
if ! command -v pm2 >/dev/null 2>&1; then

    NPM_PREFIX="$(npm prefix -g)"
    PM2_BIN="$NPM_PREFIX/bin"

    if [ -x "$PM2_BIN/pm2" ]; then
        export PATH="$PM2_BIN:$PATH"
        echo "[+] Added npm global bin to PATH for this installer."
    fi
fi

if ! command -v pm2 >/dev/null 2>&1; then
    echo
    echo "[!] PM2 was installed but could not be found in PATH."
    echo
    echo "Run:"
    echo
    echo '  export PATH="$(npm prefix -g)/bin:$PATH"'
    echo
    echo "Then run this installer again."
    exit 1
fi

echo "[+] PM2: $(pm2 -v)"

# -----------------------------
# Stop existing PM2 process
# -----------------------------

echo
echo "[*] Checking existing Factory 42 process..."

if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
    echo "[*] Existing process found."
    pm2 delete "$APP_NAME"
fi

# -----------------------------
# Start application
# -----------------------------

echo
echo "[*] Starting Factory 42 Rich Presence..."

cd "$APP_DIR"

pm2 start index.js --name "$APP_NAME"

# -----------------------------
# Save PM2 process list
# -----------------------------

echo
echo "[*] Saving PM2 process list..."

pm2 save

# -----------------------------
# Configure startup
# -----------------------------

echo
echo "======================================"
echo " PM2 startup configuration"
echo "======================================"
echo

if [ "$PLATFORM" = "Linux" ]; then

    echo "[*] Configuring PM2 startup..."

    STARTUP_OUTPUT="$(pm2 startup 2>&1 || true)"

    echo "$STARTUP_OUTPUT"

    STARTUP_COMMAND="$(echo "$STARTUP_OUTPUT" | grep -E '^sudo ' | tail -1 || true)"

    if [ -n "$STARTUP_COMMAND" ]; then
        echo
        echo "[*] Running PM2 startup command..."
        eval "$STARTUP_COMMAND"
        pm2 save
    else
        echo
        echo "[!] Could not automatically detect the PM2 startup command."
        echo "Run 'pm2 startup' manually."
    fi

elif [ "$PLATFORM" = "macOS" ]; then

    echo "[*] Configuring PM2 startup for macOS..."

    STARTUP_OUTPUT="$(pm2 startup 2>&1 || true)"

    echo "$STARTUP_OUTPUT"

    STARTUP_COMMAND="$(echo "$STARTUP_OUTPUT" | grep -E '^sudo ' | tail -1 || true)"

    if [ -n "$STARTUP_COMMAND" ]; then
        echo
        echo "[*] Running PM2 startup command..."
        eval "$STARTUP_COMMAND"
        pm2 save
    else
        echo
        echo "[!] Could not automatically detect the PM2 startup command."
        echo
        echo "Run:"
        echo
        echo "  pm2 startup"
        echo
        echo "and follow the command PM2 provides."
    fi

fi

# -----------------------------
# Final status
# -----------------------------

echo
echo "======================================"
echo " Installation complete"
echo "======================================"
echo

pm2 status

echo
echo "Application directory:"
echo "  $APP_DIR"
echo
echo "PM2 process:"
echo "  $APP_NAME"
echo
echo "Useful commands:"
echo "  pm2 status"
echo "  pm2 logs $APP_NAME"
echo "  pm2 restart $APP_NAME"
echo "  pm2 stop $APP_NAME"
echo
