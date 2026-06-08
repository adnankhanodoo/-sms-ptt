#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  SMS IoT - MQTT Broker WebSocket Setup
#  Run on the machine that has Mosquitto Docker container
#  This enables WebSocket port 9001 for browser connections
#  Usage: bash setup-mqtt-ws.sh
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   SMS IoT - MQTT WebSocket Setup         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Find mosquitto container ──────────────────────────────
CONTAINER=$(docker ps --format '{{.Names}}' | grep -i mosquitto | head -1)
[ -z "$CONTAINER" ] && err "No mosquitto container found. Is Docker running?"
log "Mosquitto container: $CONTAINER"

# ── Check if 9001 already open ────────────────────────────
if nc -zv localhost 9001 2>/dev/null; then
  log "Port 9001 already open — nothing to do"
  exit 0
fi

# ── Find compose file ─────────────────────────────────────
COMPOSE_FILE=$(docker inspect "$CONTAINER" 2>/dev/null | \
  grep -o '"com.docker.compose.project.config_files": "[^"]*"' | \
  grep -o '/[^"]*' | head -1)

[ -z "$COMPOSE_FILE" ] && err "Cannot find docker-compose.yml for $CONTAINER"
log "Compose file: $COMPOSE_FILE"

# ── Add port 9001 to compose file ────────────────────────
info "Adding WebSocket port 9001..."
sudo sed -i 's/ports: \["1883:1883"\]/ports: ["1883:1883", "9001:9001"]/' "$COMPOSE_FILE"

# ── Add websocket listener to mosquitto config ────────────
info "Adding WebSocket listener to mosquitto config..."
COMPOSE_DIR=$(dirname "$COMPOSE_FILE")
CONF_FILE="$COMPOSE_DIR/mosquitto/mosquitto.conf"

if [ -f "$CONF_FILE" ]; then
  if ! grep -q "9001" "$CONF_FILE"; then
    echo "" >> "$CONF_FILE"
    echo "listener 9001" >> "$CONF_FILE"
    echo "protocol websockets" >> "$CONF_FILE"
    log "WebSocket listener added to config"
  else
    log "WebSocket listener already in config"
  fi
else
  warn "Config file not found at $CONF_FILE — adding via docker exec"
  docker exec "$CONTAINER" sh -c \
    "printf '\nlistener 9001\nprotocol websockets\n' >> /mosquitto/config/mosquitto.conf"
fi

# ── Restart container ─────────────────────────────────────
info "Restarting mosquitto..."
sudo docker compose -f "$COMPOSE_FILE" up -d mosquitto
sleep 2

# ── Verify ────────────────────────────────────────────────
if nc -zv localhost 9001 2>/dev/null; then
  log "Port 9001 WebSocket now open"
else
  err "Port 9001 still not open — check compose file manually"
fi

echo ""
log "MQTT WebSocket setup complete!"
log "Port 1883 — MQTT (TCP)"
log "Port 9001 — MQTT (WebSocket for browsers)"
echo ""
