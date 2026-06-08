#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  SMS IoT - PTT Client Setup
#  Usage: bash install-client.sh <TOWER_IP>
#  Example: bash install-client.sh 100.84.108.142
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     SMS IoT PTT - Client Setup           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

TOWER_IP="${1:-}"
if [ -z "$TOWER_IP" ]; then
  read -p "Enter Tower IP address: " TOWER_IP
fi
[ -z "$TOWER_IP" ] && echo "Tower IP required." && exit 1
log "Tower IP: $TOWER_IP"

# ── Test connection ───────────────────────────────────────
info "Testing connection to tower..."
if nc -zv "$TOWER_IP" 8090 2>/dev/null; then
  log "Tower reachable ✓"
else
  warn "Cannot reach tower — make sure tower server is running"
fi

# ── Chrome flag for HTTP mic ──────────────────────────────
info "Configuring Chrome mic access for HTTP..."
CHROME_FLAG_FILE="$HOME/.config/chromium-flags.conf"
echo "--unsafely-treat-insecure-origin-as-secure=http://${TOWER_IP}:8090" > "$CHROME_FLAG_FILE"
log "Chrome configured"

# ── Desktop shortcut ──────────────────────────────────────
mkdir -p "$HOME/Desktop"
cat > "$HOME/Desktop/SMS-PTT.desktop" << DEOF
[Desktop Entry]
Type=Application
Name=SMS IoT PTT
Exec=xdg-open http://${TOWER_IP}:8090
Icon=audio-input-microphone
Terminal=false
DEOF
chmod +x "$HOME/Desktop/SMS-PTT.desktop"
log "Desktop shortcut created"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Client Setup Complete!               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
log "Open this in browser:"
echo ""
echo "   👉  http://${TOWER_IP}:8090"
echo ""
warn "Allow microphone when browser asks!"
echo ""
