#!/usr/bin/env bash
# Appsmith Critical Issues Auto-Fix Script
# Fixes: Node version, Java version, gitleaks installation
# Safe, idempotent, no sudo required
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[FIX]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die() { error "$*"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 APPSMITH CRITICAL ISSUES AUTO-FIX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "OS: $OS | Arch: $ARCH"
echo ""

# ---------- 1. FIX NODE.JS ----------
log "Step 1/3: Fixing Node.js version..."

NODE_EXPECTED=$(cat app/client/.nvmrc)
info "Target version: $NODE_EXPECTED"

# Check if nvm is installed
if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    log "Found nvm installation"
elif [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    log "Found nvm installation"
else
    error "nvm not found"
    info "Installing nvm..."
    
    # Install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Source nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    
    if command -v nvm >/dev/null 2>&1; then
        log "✅ nvm installed successfully"
    else
        die "Failed to install nvm. Please install manually: https://github.com/nvm-sh/nvm"
    fi
fi

# Check current Node version
CURRENT_NODE=$(node -v 2>/dev/null || echo "none")
info "Current Node: $CURRENT_NODE"

# Install and use correct Node version
if [[ "$CURRENT_NODE" != "$NODE_EXPECTED" ]]; then
    info "Installing Node $NODE_EXPECTED..."
    nvm install "$NODE_EXPECTED"
    nvm use "$NODE_EXPECTED"
    
    # Set as default for new shells
    nvm alias default "$NODE_EXPECTED"
    
    log "✅ Node $(node -v) active and set as default"
else
    log "✅ Node $NODE_EXPECTED already active"
fi

# Verify
NODE_VERSION=$(node -v)
if [[ "$NODE_VERSION" == "$NODE_EXPECTED" ]]; then
    log "✅ Node.js version verified: $NODE_VERSION"
else
    die "Node version mismatch after fix: expected $NODE_EXPECTED, got $NODE_VERSION"
fi

echo ""

# ---------- 2. FIX JAVA ----------
log "Step 2/3: Fixing Java version..."

JAVA_EXPECTED=$(grep -oP '<java\.version>\K[^<]+' app/server/pom.xml | head -1)
info "Target version: Java $JAVA_EXPECTED"

# Check if Java is already correct
CURRENT_JAVA=$(java -version 2>&1 | head -n1 | grep -oP '\d+\.\d+' | head -1 || echo "none")
info "Current Java: $CURRENT_JAVA"

if [[ "$CURRENT_JAVA" == "$JAVA_EXPECTED" ]]; then
    log "✅ Java $JAVA_EXPECTED already active"
else
    info "Fixing Java version..."
    
    # Check if SDKMAN is installed
    if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        log "Found SDKMAN installation"
    elif command -v sdk >/dev/null 2>&1; then
        log "Found SDKMAN installation"
    else
        error "SDKMAN not found"
        info "Installing SDKMAN..."
        
        # Install SDKMAN
        export SDKMAN_DIR="$HOME/.sdkman"
        curl -s "https://get.sdkman.io" | bash
        
        # Source SDKMAN
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        
        if command -v sdk >/dev/null 2>&1; then
            log "✅ SDKMAN installed successfully"
        else
            die "Failed to install SDKMAN. Please install manually: https://sdkman.io/"
        fi
    fi
    
    # Install Java 17 via SDKMAN (Temurin distribution)
    info "Installing Java $JAVA_EXPECTED via SDKMAN..."
    
    # Try to install, but don't fail if already installed
    sdk install java 17.0.10-tem || info "Java 17 may already be installed"
    
    # Use Java 17
    sdk use java 17.0.10-tem || sdk default java 17.0.10-tem
    
    # Verify
    JAVA_VERSION=$(java -version 2>&1 | head -n1 | grep -oP '\d+\.\d+' | head -1)
    if [[ "$JAVA_VERSION" == "$JAVA_EXPECTED" ]]; then
        log "✅ Java $JAVA_VERSION active"
    else
        warn "Java version is $JAVA_VERSION, expected $JAVA_EXPECTED"
        info "You may need to run: sdk use java 17.0.10-tem"
    fi
fi

echo ""

# ---------- 3. FIX GITLEAKS ----------
log "Step 3/3: Installing gitleaks..."

GITLEAKS_BIN="./scripts/gitleaks"
GITLEAKS_VERSION="8.18.0"

if [[ -x "$GITLEAKS_BIN" ]]; then
    CURRENT_VERSION=$("$GITLEAKS_BIN" version 2>/dev/null | head -n1 || echo "unknown")
    log "✅ gitleaks already installed: $CURRENT_VERSION"
else
    info "Downloading gitleaks $GITLEAKS_VERSION..."
    
    # Create scripts directory if it doesn't exist
    mkdir -p scripts
    
    # Determine download URL based on OS and architecture
    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64) GITLEAKS_ARCH="linux_x64" ;;
                aarch64|arm64) GITLEAKS_ARCH="linux_arm64" ;;
                *) die "Unsupported Linux architecture: $ARCH" ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64) GITLEAKS_ARCH="darwin_x64" ;;
                arm64) GITLEAKS_ARCH="darwin_arm64" ;;
                *) die "Unsupported macOS architecture: $ARCH" ;;
            esac
            ;;
        *)
            die "Unsupported OS: $OS"
            ;;
    esac
    
    DOWNLOAD_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${GITLEAKS_ARCH}.tar.gz"
    
    info "Downloading from: $DOWNLOAD_URL"
    
    # Download and extract
    if curl -sSfL "$DOWNLOAD_URL" | tar -xz -C scripts gitleaks; then
        chmod +x "$GITLEAKS_BIN"
        log "✅ gitleaks $GITLEAKS_VERSION installed to $GITLEAKS_BIN"
    else
        die "Failed to download gitleaks. URL: $DOWNLOAD_URL"
    fi
fi

# Run gitleaks scan
info "Running gitleaks scan..."
if "$GITLEAKS_BIN" detect --source . --verbose --no-git; then
    log "✅ Gitleaks scan clean - no secrets detected"
else
    warn "Gitleaks detected potential secrets!"
    error "Please review the output above and remove any secrets before committing"
    exit 1
fi

echo ""

# ---------- 4. VERIFY ALL FIXES ----------
log "Step 4/4: Verifying all fixes..."
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 VERIFICATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VERIFICATION_FAILED=0

# Verify Node
NODE_VERSION=$(node -v)
if [[ "$NODE_VERSION" == "$NODE_EXPECTED" ]]; then
    log "✅ Node.js: $NODE_VERSION"
else
    error "❌ Node.js: $NODE_VERSION (expected $NODE_EXPECTED)"
    VERIFICATION_FAILED=1
fi

# Verify Java
JAVA_VERSION=$(java -version 2>&1 | head -n1 | grep -oP '\d+\.\d+' | head -1)
if [[ "$JAVA_VERSION" == "$JAVA_EXPECTED" ]]; then
    log "✅ Java: $JAVA_VERSION"
else
    error "❌ Java: $JAVA_VERSION (expected $JAVA_EXPECTED)"
    VERIFICATION_FAILED=1
fi

# Verify gitleaks
if [[ -x "$GITLEAKS_BIN" ]]; then
    GITLEAKS_VER=$("$GITLEAKS_BIN" version 2>/dev/null | head -n1)
    log "✅ gitleaks: $GITLEAKS_VER"
else
    error "❌ gitleaks: not found at $GITLEAKS_BIN"
    VERIFICATION_FAILED=1
fi

echo ""

if [[ $VERIFICATION_FAILED -eq 0 ]]; then
    log "🎉 ALL CRITICAL ISSUES FIXED!"
    echo ""
    info "Next steps:"
    echo "  1. Install dependencies: cd app/client && corepack enable && yarn install"
    echo "  2. Run pre-flight check: ./scripts/pre-flight-check.sh"
    echo "  3. Commit and push your changes"
    echo ""
    
    # Optionally run pre-flight check if it exists
    if [[ -x "./scripts/pre-flight-check.sh" ]]; then
        info "Running pre-flight check now..."
        echo ""
        ./scripts/pre-flight-check.sh || {
            warn "Pre-flight check found additional issues"
            info "Follow the instructions above to fix them"
            exit 1
        }
    fi
    
    log "✅ Ready to commit!"
    exit 0
else
    error "Some issues remain - please review the output above"
    exit 1
fi
