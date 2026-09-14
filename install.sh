#!/usr/bin/env bash

set -e

REPO="git@github.com:formalParrot/factory42-rpc.git"
APP_NAME="factory42"
APP_DIR="$HOME/factory42-rpc"

echo
echo "=========================================="
echo " Factory 42 Rich Presence Installer"
echo "=========================================="
echo

# ==========================================
# Detect OS
# ==========================================

OS="$(uname -s)"

case "$OS" in
    Darwin)
        PLATFORM="macOS"
        ;;
    Linux)
        PLATFORM="Linux"
        ;;
    *)
        echo "[!] Unsupported operating system: $OS"
        exit 1
        ;;
esac

echo "[+] Operating system: $PLATFORM"

# ==========================================
# Helper: command exists
# ==========================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ==========================================
# Install Git
# ==========================================

if command_exists git; then
    echo "[+] Git: $(git --version)"
else
    echo "[!] Git is not installed."
    echo "[*] Installing Git..."

    if [ "$PLATFORM" = "macOS" ]; then

        if command_exists brew; then
            brew install git
        else
            echo
            echo "[*] Homebrew is not installed."
            echo "[*] Installing Homebrew..."

            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            if [ -x "/opt/homebrew/bin/brew" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -x "/usr/local/bin/brew" ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi

            brew install git
        fi

    elif [ "$PLATFORM" = "Linux" ]; then

        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y git

        elif command_exists dnf; then
            sudo dnf install -y git

        elif command_exists pacman; then
            sudo pacman -Sy --noconfirm git

        elif command_exists zypper; then
            sudo zypper install -y git

        else
            echo "[!] Could not determine how to install Git."
            echo "[!] Install Git manually and run this script again."
            exit 1
        fi
    fi
fi

if ! command_exists git; then
    echo "[!] Git is still unavailable."
    exit 1
fi

echo "[+] Git ready."

# ==========================================
# Install Node.js + npm
# ==========================================

if command_exists node && command_exists npm; then

    echo "[+] Node.js: $(node --version)"
    echo "[+] npm: $(npm --version)"

else

    echo "[!] Node.js/npm not found."
    echo "[*] Installing Node.js LTS..."

    if [ "$PLATFORM" = "macOS" ]; then

        if ! command_exists brew; then
            echo "[!] Homebrew is required to install Node.js."
            exit 1
        fi

        brew install node

    elif [ "$PLATFORM" = "Linux" ]; then

        if command_exists apt-get; then

            # NodeSource provides a current Node.js LTS release.
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs

        elif command_exists dnf; then

            sudo dnf install -y nodejs npm

        elif command_exists pacman; then

            sudo pacman -Sy --noconfirm nodejs npm

        elif command_exists zypper; then

            sudo zypper install -y nodejs npm

        else
            echo "[!] Could not determine how to install Node.js."
            echo "[!] Install Node.js manually and run this script again."
            exit 1
        fi
    fi
fi

if ! command_exists node; then
    echo "[!] Node.js installation failed."
    exit 1
fi

if ! command_exists npm; then
    echo "[!] npm installation failed."
    exit 1
fi

echo "[+] Node.js: $(node --version)"
echo "[+] npm: $(npm --version)"

# ==========================================
# Clone / update repository
# ==========================================

echo
echo "[*] Preparing repository..."

if [ -d "$APP_DIR/.git" ]; then

    echo "[+] Repository already exists."
    cd "$APP_DIR"

    echo "[*] Pulling latest changes..."
    git pull --ff-only

else

    if [ -d "$APP_DIR" ]; then
        echo "[!] $APP_DIR already exists but is not a Git repository."
        echo "[!] Refusing to overwrite it."
        exit 1
    fi

    echo "[*] Cloning repository..."
    git clone "$REPO" "$APP_DIR"

    cd "$APP_DIR"
fi

# ==========================================
# Install dependencies
# ==========================================

echo
echo "[*] Installing npm dependencies..."

npm install

echo "[+] Dependencies installed."

# ==========================================
# Create .env
# ==========================================

echo
echo "=========================================="
echo " Factory 42 API Token"
echo "=========================================="
echo
echo "Enter your Factory 42 API token."
echo "The input will not be displayed."
echo

read -r -s -p "FACTORY_42_TOKEN: " FACTORY_42_TOKEN
echo

if [ -z "$FACTORY_42_TOKEN" ]; then
    echo "[!] Token cannot be empty."
    exit 1
fi

cat > .env <<EOF
FACTORY_42_TOKEN='$FACTORY_42_TOKEN'
EOF

chmod 600 .env

echo "[+] .env created."

# ==========================================
# Install PM2
# ==========================================

echo
echo "[*] Checking PM2..."

if command_exists pm2; then

    echo "[+] PM2: $(pm2 --version)"

else

    echo "[*] Installing PM2 globally..."

    npm install -g pm2

    # npm global bin may not already be in PATH.
    NPM_PREFIX="$(npm prefix -g)"
    NPM_BIN="$NPM_PREFIX/bin"

    if [ -d "$NPM_BIN" ]; then
        export PATH="$NPM_BIN:$PATH"
    fi
fi

if ! command_exists pm2; then
    echo
    echo "[!] PM2 was installed but cannot be found in PATH."
    echo
    echo "Add this to your shell configuration:"
    echo
    echo "export PATH=\"$(npm prefix -g)/bin:\$PATH\""
    echo
    exit 1
fi

echo "[+] PM2: $(pm2 --version)"

# ==========================================
# Remove existing PM2 process
# ==========================================

echo
echo "[*] Checking existing PM2 process..."

if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
    echo "[*] Removing existing $APP_NAME process..."
    pm2 delete "$APP_NAME"
fi

# ==========================================
# Start application
# ==========================================

echo
echo "[*] Starting Factory 42 Rich Presence..."

pm2 start index.js --name factory42

# ==========================================
# Save PM2 process list
# ==========================================

echo
echo "[*] Saving PM2 process list..."

pm2 save

# ==========================================
# Configure startup
# ==========================================

echo
echo "=========================================="
echo " PM2 Startup"
echo "=========================================="
echo

if [ "$PLATFORM" = "Linux" ]; then

    echo "[*] Configuring PM2 startup..."

    STARTUP_OUTPUT="$(pm2 startup 2>&1 || true)"

    echo "$STARTUP_OUTPUT"

    STARTUP_COMMAND="$(echo "$STARTUP_OUTPUT" | grep -E '^sudo ' | tail -1 || true)"

    if [ -n "$STARTUP_COMMAND" ]; then
        echo
        echo "[*] Running startup command..."
        eval "$STARTUP_COMMAND"
        pm2 save
        echo "[+] PM2 startup configured."
    else
        echo
        echo "[!] PM2 did not provide an automatic startup command."
        echo "[!] Run 'pm2 startup' manually if required."
    fi

elif [ "$PLATFORM" = "macOS" ]; then

    echo "[*] Configuring PM2 startup..."

    STARTUP_OUTPUT="$(pm2 startup 2>&1 || true)"

    echo "$STARTUP_OUTPUT"

    STARTUP_COMMAND="$(echo "$STARTUP_OUTPUT" | grep -E '^sudo ' | tail -1 || true)"

    if [ -n "$STARTUP_COMMAND" ]; then
        echo
        echo "[*] Running startup command..."
        eval "$STARTUP_COMMAND"
        pm2 save
        echo "[+] PM2 startup configured."
    else
        echo
        echo "[!] PM2 did not provide an automatic startup command."
        echo
        echo "Run:"
        echo
        echo "  pm2 startup"
        echo
        echo "and follow the command it provides."
    fi

fi

# ==========================================
# Verify
# ==========================================

echo
echo "=========================================="
echo " Installation complete"
echo "=========================================="
echo

pm2 status

echo
echo "Application:"
echo "  $APP_DIR"
echo
echo "PM2 name:"
echo "  $APP_NAME"
echo
echo "Useful commands:"
echo "  pm2 status"
echo "  pm2 logs factory42"
echo "  pm2 restart factory42"
echo "  pm2 stop factory42"
echo
