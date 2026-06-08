#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  SMS IoT - PTT Client Setup
#  Run on the client machine (with browser)
#  Usage: bash install-client.sh <TOWER_IP>
#  Example: bash install-client.sh 100.84.108.142
# ═══════════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     SMS IoT PTT - Client Setup           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Get tower IP ──────────────────────────────────────────
TOWER_IP="${1:-}"

if [ -z "$TOWER_IP" ]; then
  read -p "Enter Tower machine IP: " TOWER_IP
fi

[ -z "$TOWER_IP" ] && echo "Tower IP required." && exit 1
log "Tower IP: $TOWER_IP"

# ── Test connection ───────────────────────────────────────
info "Testing connection to tower..."
if nc -zv "$TOWER_IP" 8090 2>/dev/null; then
  log "Tower reachable on port 8090"
else
  warn "Cannot reach tower on port 8090 — make sure tower is running"
fi

# ── Create desktop shortcut ───────────────────────────────
DESKTOP_FILE="$HOME/Desktop/SMS-PTT.desktop"
mkdir -p "$HOME/Desktop"

cat > "$DESKTOP_FILE" << DEOF
[Desktop Entry]
Type=Application
Name=SMS IoT PTT
Comment=Push to Talk Client
Exec=xdg-open http://${TOWER_IP}:8090/client.html
Icon=audio-input-microphone
Terminal=false
Categories=Network;
DEOF
chmod +x "$DESKTOP_FILE"
log "Desktop shortcut created"

# ── Chrome flag for HTTP mic access ──────────────────────
info "Configuring Chrome for mic access on HTTP..."

CHROME_FLAGS="$HOME/.config/chromium/Local State"
mkdir -p "$(dirname "$CHROME_FLAGS")"

# Add to Chrome unsafely-treat-insecure-origin-as-secure
CHROME_FLAG_FILE="$HOME/.config/chromium-flags.conf"
echo "--unsafely-treat-insecure-origin-as-secure=http://${TOWER_IP}:8090" > "$CHROME_FLAG_FILE"
log "Chrome mic flag set"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Client Setup Complete!               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
log "Open this URL in browser:"
echo ""
echo "   👉  http://${TOWER_IP}:8090/client.html"
echo ""
info "Or use the desktop shortcut: SMS IoT PTT"
echo ""
warn "Allow microphone when browser asks!"
echo ""
