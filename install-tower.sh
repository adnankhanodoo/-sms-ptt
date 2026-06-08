#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  SMS IoT - PTT Tower Setup
#  One direction: Client speaks → Tower hears
#  Usage: bash install-tower.sh
# ═══════════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     SMS IoT PTT - Tower Setup            ║"
echo "║     Client speaks → Tower hears          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Check Node.js ─────────────────────────────────────────
if ! command -v node &>/dev/null; then
  info "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
log "Node.js $(node --version)"

# ── Install dependencies ──────────────────────────────────
info "Installing system dependencies..."
sudo apt-get install -y -qq libasound2-dev ffmpeg
log "Dependencies installed"

# ── Check speaker/mic ─────────────────────────────────────
info "Checking audio devices..."
MIC=$(arecord -l 2>/dev/null | grep "card" | head -1)
SPK=$(aplay -l 2>/dev/null | grep "card" | head -1)
[ -n "$MIC" ] && log "Mic: $MIC" || warn "No mic detected"
[ -n "$SPK" ] && log "Speaker: $SPK" || warn "No speaker detected"

# ── Create project ────────────────────────────────────────
INSTALL_DIR="$HOME/sms-ptt-tower"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
log "Install dir: $INSTALL_DIR"

# ── package.json ──────────────────────────────────────────
cat > package.json << 'EOF'
{
  "name": "sms-ptt-tower",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "ws": "^8.0.0",
    "speaker": "^0.5.0"
  }
}
EOF

# ── server.js ─────────────────────────────────────────────
cat > server.js << 'EOF'
const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');
const Speaker = require('speaker');

const PORT = 8090;

const httpServer = http.createServer((req, res) => {
  const file = path.join(__dirname, 'client.html');
  fs.readFile(file, (err, data) => {
    if(err){ res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, {'Content-Type':'text/html','Cache-Control':'no-cache'});
    res.end(data);
  });
});

const wss = new WebSocket.Server({ server: httpServer });

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  console.log(`[${new Date().toLocaleTimeString()}] Client connected: ${ip}`);

  const speaker = new Speaker({
    channels: 1,
    bitDepth: 16,
    sampleRate: 16000,
    signed: true
  });

  speaker.on('error', e => {});

  ws.on('message', (data) => {
    if(speaker.writable) speaker.write(Buffer.from(data));
  });

  ws.on('close', () => {
    console.log(`[${new Date().toLocaleTimeString()}] Client disconnected: ${ip}`);
    try{ speaker.end(); }catch(e){}
  });

  ws.on('error', () => {});
});

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('🗼  SMS IoT PTT Tower');
  console.log('─────────────────────────────────────');
  console.log(`🌐 Client page : http://0.0.0.0:${PORT}`);
  console.log('─────────────────────────────────────');
  console.log('');
});
EOF

# ── client.html ───────────────────────────────────────────
cat > client.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SMS IoT PTT</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',sans-serif;background:#0f1117;color:#e0e0e0;display:flex;align-items:center;justify-content:center;height:100vh;user-select:none}
.card{background:#1a1d27;border:1px solid #2a2d3a;border-radius:16px;padding:40px;text-align:center;width:320px}
h1{font-size:22px;color:#fff;margin-bottom:6px}
.sub{font-size:13px;color:#666;margin-bottom:32px}
.btn{width:160px;height:160px;border-radius:50%;border:none;cursor:pointer;font-size:56px;display:flex;align-items:center;justify-content:center;margin:0 auto 24px;transition:all 0.1s;touch-action:none;outline:none;-webkit-tap-highlight-color:transparent}
.btn.idle{border:3px solid #333;background:#1e2130}
.btn.ready{border:3px solid #22c55e;background:#0f2a1a;box-shadow:0 0 24px #22c55e55}
.btn.active{border:3px solid #ef4444;background:#2a0f0f;box-shadow:0 0 40px #ef444499;transform:scale(0.94)}
.btn:disabled{opacity:.35;cursor:not-allowed}
.lbl{font-size:16px;font-weight:600;margin-bottom:4px}
.hint{font-size:11px;color:#444;margin-bottom:24px}
.dots{display:flex;gap:16px;justify-content:center;margin-bottom:16px}
.di{display:flex;align-items:center;gap:6px;font-size:12px;color:#666}
.dot{width:8px;height:8px;border-radius:50%;background:#333}
.dot.g{background:#22c55e;box-shadow:0 0 6px #22c55e}
.dot.r{background:#ef4444;box-shadow:0 0 8px #ef4444}
.log{background:#0f1117;border-radius:8px;padding:8px;font-size:11px;color:#555;text-align:left;max-height:80px;overflow-y:auto;font-family:monospace}
.ok{color:#22c55e}.info{color:#3b82f6}.warn{color:#f59e0b}
</style>
</head>
<body>
<div class="card">
  <h1>📱 SMS IoT PTT</h1>
  <p class="sub">Press and hold to speak</p>
  <button class="btn idle" id="btn" disabled>🎙️</button>
  <div class="lbl" id="lbl">Starting...</div>
  <div class="hint" id="hint">Please wait</div>
  <div class="dots">
    <div class="di"><div class="dot" id="dM"></div><span>Mic</span></div>
    <div class="di"><div class="dot" id="dC"></div><span>Tower</span></div>
    <div class="di"><div class="dot" id="dP"></div><span>PTT</span></div>
  </div>
  <div class="log" id="log"></div>
</div>
<script>
const SAMPLE_RATE = 16000;
const BUFFER_SIZE = 256;
let ws, audioCtx, processor, source, stream;
let connected = false, transmitting = false;

function L(m,t){const e=document.getElementById('log'),d=document.createElement('div');d.className=t||'';d.textContent='['+new Date().toLocaleTimeString()+'] '+m;e.appendChild(d);e.scrollTop=e.scrollHeight;}
function D(id,c){document.getElementById(id).className='dot'+(c?' '+c:'');}
function UI(bc,l,h,en){const b=document.getElementById('btn');b.className='btn '+bc;b.disabled=!en;document.getElementById('lbl').textContent=l;document.getElementById('hint').textContent=h;}

function f32ToI16(f32){
  const buf=new ArrayBuffer(f32.length*2);
  const view=new DataView(buf);
  for(let i=0;i<f32.length;i++){
    const s=Math.max(-1,Math.min(1,f32[i]));
    view.setInt16(i*2,s<0?s*0x8000:s*0x7FFF,true);
  }
  return buf;
}

function connectWS(){
  ws=new WebSocket('ws://'+location.hostname+':8090');
  ws.binaryType='arraybuffer';
  ws.onopen=()=>{connected=true;D('dC','g');UI('ready','Hold to Talk','Press and hold',true);L('Tower connected','ok');};
  ws.onclose=()=>{connected=false;D('dC','');transmitting=false;UI('idle','Reconnecting...','Please wait',false);L('Reconnecting...','warn');setTimeout(connectWS,2000);};
  ws.onerror=()=>{};
}

async function init(){
  try{
    stream=await navigator.mediaDevices.getUserMedia({
      audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true,sampleRate:SAMPLE_RATE,latency:0}
    });
    D('dM','g');L('Mic ready','ok');
    audioCtx=new (window.AudioContext||window.webkitAudioContext)({sampleRate:SAMPLE_RATE,latencyHint:'interactive'});
    source=audioCtx.createMediaStreamSource(stream);
    processor=audioCtx.createScriptProcessor(BUFFER_SIZE,1,1);
    processor.onaudioprocess=e=>{
      if(!transmitting||!connected||ws.readyState!==1)return;
      ws.send(f32ToI16(e.inputBuffer.getChannelData(0)));
    };
    source.connect(processor);
    processor.connect(audioCtx.destination);
    connectWS();
  }catch(e){L('Mic error: '+e.message,'warn');}
}

function pttOn(){if(!connected)return;transmitting=true;D('dP','r');UI('active','🔴 Transmitting','Release to stop',true);L('PTT ON','info');}
function pttOff(){transmitting=false;D('dP','');if(connected)UI('ready','Hold to Talk','Press and hold',true);L('PTT OFF','info');}

const B=document.getElementById('btn');
B.addEventListener('mousedown',pttOn);
B.addEventListener('mouseup',pttOff);
B.addEventListener('mouseleave',pttOff);
B.addEventListener('touchstart',e=>{e.preventDefault();pttOn();},{passive:false});
B.addEventListener('touchend',e=>{e.preventDefault();pttOff();},{passive:false});
document.addEventListener('keydown',e=>{if(e.code==='Space'&&!e.repeat){e.preventDefault();pttOn();}});
document.addEventListener('keyup',e=>{if(e.code==='Space'){e.preventDefault();pttOff();}});

init();
</script>
</body>
</html>
HTMLEOF

# ── npm install ───────────────────────────────────────────
info "Installing Node dependencies..."
npm install --silent
log "Dependencies installed"

# ── systemd service ───────────────────────────────────────
info "Setting up systemd service..."
sudo tee /etc/systemd/system/sms-ptt-tower.service > /dev/null << SVCEOF
[Unit]
Description=SMS IoT PTT Tower
After=network.target sound.target

[Service]
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
User=${USER}
Environment=HOME=/home/${USER}
Environment=PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable sms-ptt-tower

# Enable user lingering so service starts without login
sudo loginctl enable-linger "$USER" 2>/dev/null || true

# Start as user service for audio access
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/sms-ptt-tower.service << USVCEOF
[Unit]
Description=SMS IoT PTT Tower
After=network.target

[Service]
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
USVCEOF

systemctl --user daemon-reload
systemctl --user enable --now sms-ptt-tower
log "Service enabled and started"

# ── Done ──────────────────────────────────────────────────
TOWER_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Tower Setup Complete!                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
log "Tower IP     : $TOWER_IP"
log "Client URL   : http://$TOWER_IP:8090"
echo ""
log "Client opens browser → http://$TOWER_IP:8090"
log "Press PTT button → Tower hears voice"
echo ""
