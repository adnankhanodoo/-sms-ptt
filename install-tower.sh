#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  SMS IoT - PTT Tower Setup
#  Run on the headless "tower" machine (no monitor)
#  Usage: bash install-tower.sh <MQTT_BROKER_IP>
#  Example: bash install-tower.sh 100.84.208.88
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     SMS IoT PTT - Tower Setup            ║"
echo "║     Headless audio monitor node          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Get MQTT broker IP ────────────────────────────────────
MQTT_IP="${1:-}"

if [ -z "$MQTT_IP" ]; then
  # Try to auto-detect via NetBird
  if command -v netbird &>/dev/null; then
    MQTT_IP=$(netbird status 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | grep "^100\." | head -1)
  fi
fi

if [ -z "$MQTT_IP" ]; then
  echo ""
  warn "Could not auto-detect MQTT broker IP."
  read -p "Enter MQTT broker IP (your dev machine NetBird IP): " MQTT_IP
fi

[ -z "$MQTT_IP" ] && err "MQTT IP is required."
log "MQTT broker IP: $MQTT_IP"

# ── Get current machine IP ────────────────────────────────
TOWER_IP=$(hostname -I | awk '{print $1}')
log "Tower IP: $TOWER_IP"

# ── Install dependencies ──────────────────────────────────
info "Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq --no-install-recommends xvfb pulseaudio pulseaudio-utils chromium-browser curl netcat-openbsd
# nodejs already installed via nodesource
#
log "Dependencies installed"

# ── Check mic ─────────────────────────────────────────────
info "Checking microphone..."
MIC=$(arecord -l 2>/dev/null | grep "card" | head -1)
if [ -z "$MIC" ]; then
  warn "No microphone detected — make sure USB mic is plugged in"
else
  log "Microphone found: $MIC"
fi

# ── Create project folder ─────────────────────────────────
INSTALL_DIR="/home/$USER/sms-ptt"
mkdir -p "$INSTALL_DIR/public"
cd "$INSTALL_DIR"
log "Install directory: $INSTALL_DIR"

# ── Write package.json ────────────────────────────────────
cat > package.json << 'EOF'
{
  "name": "sms-ptt",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mqtt": "^5.3.4"
  }
}
EOF

# ── Write server.js ───────────────────────────────────────
cat > server.js << SERVEREOF
const express = require('express');
const http = require('http');
const path = require('path');
const mqtt = require('mqtt');

const app = express();
const server = http.createServer(app);

const PORT = 8090;
const MQTT_HOST = '${MQTT_IP}';
const MQTT_PORT = 1883;
const MQTT_TOPIC = 'sms/webrtc/signal';

app.use(express.static(path.join(__dirname, 'public')));

const mqttClient = mqtt.connect(\`mqtt://\${MQTT_HOST}:\${MQTT_PORT}\`, {
  clientId: \`sms-ptt-tower-\${Date.now()}\`,
  clean: true
});

mqttClient.on('connect', () => {
  console.log(\`✅ Connected to MQTT broker at \${MQTT_HOST}:\${MQTT_PORT}\`);
});

mqttClient.on('error', (err) => {
  console.error('❌ MQTT Error:', err.message);
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    role: 'tower',
    mqtt: mqttClient.connected ? 'connected' : 'disconnected',
    mqtt_host: \`\${MQTT_HOST}:\${MQTT_PORT}\`,
    tower_ip: '${TOWER_IP}'
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('🗼  SMS IoT PTT Tower');
  console.log('─────────────────────────────────────');
  console.log(\`🌐 Tower page : http://localhost:\${PORT}/tower.html\`);
  console.log(\`🔍 Health     : http://localhost:\${PORT}/health\`);
  console.log('─────────────────────────────────────');
});
SERVEREOF

# ── Write tower.html ──────────────────────────────────────
cat > public/tower.html << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SMS IoT - Tower Monitor</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', sans-serif; background: #0f1117; color: #e0e0e0;
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; height: 100vh; }
  .card { background: #1a1d27; border: 1px solid #2a2d3a; border-radius: 16px;
    padding: 40px; text-align: center; width: 380px; }
  h1 { font-size: 20px; color: #fff; margin-bottom: 6px; }
  .subtitle { font-size: 13px; color: #666; margin-bottom: 30px; }
  .ring { width: 120px; height: 120px; border-radius: 50%; margin: 0 auto 30px;
    display: flex; align-items: center; justify-content: center; font-size: 40px;
    border: 3px solid #333; transition: all 0.3s; }
  .ring.idle     { border-color: #333; background: #1e2130; }
  .ring.ready    { border-color: #22c55e; background: #0f2a1a; box-shadow: 0 0 20px #22c55e44; }
  .ring.talking  { border-color: #f59e0b; background: #2a1f0f; box-shadow: 0 0 30px #f59e0b66; animation: pulse 1s infinite; }
  .ring.receiving { border-color: #3b82f6; background: #0f1a2a; box-shadow: 0 0 30px #3b82f666; animation: pulse 0.8s infinite; }
  @keyframes pulse { 0%,100%{transform:scale(1)} 50%{transform:scale(1.05)} }
  .label { font-size: 16px; font-weight: 600; margin-bottom: 8px; }
  .detail { font-size: 12px; color: #666; margin-bottom: 30px; }
  .dots { display: flex; gap: 12px; justify-content: center; margin-bottom: 20px; }
  .dot-item { display: flex; align-items: center; gap: 6px; font-size: 12px; color: #666; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: #333; }
  .dot.on   { background: #22c55e; box-shadow: 0 0 6px #22c55e; }
  .dot.warn { background: #f59e0b; box-shadow: 0 0 6px #f59e0b; }
  .dot.blue { background: #3b82f6; box-shadow: 0 0 6px #3b82f6; }
  .log { background: #0f1117; border-radius: 8px; padding: 10px; font-size: 11px;
    color: #555; text-align: left; max-height: 100px; overflow-y: auto; font-family: monospace; }
  .log .ok   { color: #22c55e; }
  .log .info { color: #3b82f6; }
  .log .warn { color: #f59e0b; }
  audio { display: none; }
</style>
</head>
<body>
<div class="card">
  <h1>🗼 Tower Monitor</h1>
  <p class="subtitle">Always listening — mic always open</p>
  <div class="ring idle" id="ring">🎙️</div>
  <div class="label" id="lbl">Initializing...</div>
  <div class="detail" id="det">Starting up</div>
  <div class="dots">
    <div class="dot-item"><div class="dot" id="dMqtt"></div><span>MQTT</span></div>
    <div class="dot-item"><div class="dot" id="dMic"></div><span>Mic</span></div>
    <div class="dot-item"><div class="dot" id="dPeer"></div><span>Client</span></div>
    <div class="dot-item"><div class="dot" id="dPtt"></div><span>PTT</span></div>
  </div>
  <div class="log" id="log"></div>
</div>
<audio id="remoteAudio" autoplay playsinline></audio>
<script src="https://cdnjs.cloudflare.com/ajax/libs/paho-mqtt/1.1.0/paho-mqtt.min.js"></script>
<script>
const MQTT_HOST='${MQTT_IP}', MQTT_PORT=9001, TOPIC='sms/webrtc/signal', ROLE='tower';
let mqtt,peer,stream,ready=false;
function log(m,t=''){const e=document.getElementById('log'),d=document.createElement('div');d.className=t;d.textContent='['+new Date().toLocaleTimeString()+'] '+m;e.appendChild(d);e.scrollTop=e.scrollHeight;}
function ring(s,l,d){const icons={idle:'🎙️',ready:'✅',talking:'📡',receiving:'🔊'};document.getElementById('ring').className='ring '+s;document.getElementById('ring').textContent=icons[s]||'🎙️';document.getElementById('lbl').textContent=l;document.getElementById('det').textContent=d;}
function dot(id,on,t='on'){document.getElementById(id).className='dot'+(on?' '+t:'');}
function send(d){if(!ready)return;const m=new Paho.Message(JSON.stringify({...d,from:ROLE}));m.destinationName=TOPIC;m.retained=false;mqtt.send(m);}
function connect(){
  mqtt=new Paho.Client(MQTT_HOST,MQTT_PORT,'sms-tower-'+Date.now());
  mqtt.onConnectionLost=()=>{ready=false;dot('dMqtt',false);ring('idle','MQTT Lost','Reconnecting...');setTimeout(connect,3000);};
  mqtt.onMessageArrived=msg=>{try{const d=JSON.parse(msg.payloadString);if(d.from===ROLE)return;handle(d);}catch(e){}};
  mqtt.connect({onSuccess:()=>{ready=true;dot('dMqtt',true);log('MQTT connected','ok');mqtt.subscribe(TOPIC);initMic();},
    onFailure:e=>{log('MQTT failed: '+e.errorMessage,'warn');setTimeout(connect,3000);},keepAliveInterval:30,useSSL:false});
}
async function initMic(){
  try{stream=await navigator.mediaDevices.getUserMedia({audio:true,video:false});dot('dMic',true);log('Mic ready','ok');ring('ready','Ready','Waiting for client...');send({type:'tower-ready'});}
  catch(e){log('Mic error: '+e.message,'warn');ring('idle','Mic Error',e.message);}
}
function mkPeer(){
  peer=new RTCPeerConnection({iceServers:[{urls:'stun:stun.l.google.com:19302'}]});
  if(stream)stream.getTracks().forEach(t=>peer.addTrack(t,stream));
  peer.ontrack=e=>{log('Client audio received','ok');document.getElementById('remoteAudio').srcObject=e.streams[0];};
  peer.onicecandidate=e=>{if(e.candidate)send({type:'ice',candidate:e.candidate});};
  peer.onconnectionstatechange=()=>{const s=peer.connectionState;log('Peer: '+s);
    if(s==='connected'){dot('dPeer',true,'blue');ring('talking','Connected','Mic live');}
    else if(s==='disconnected'||s==='failed'){dot('dPeer',false);dot('dPtt',false);ring('ready','Client Left','Waiting...');peer=null;}};
  return peer;
}
async function handle(d){
  if(d.type==='offer'){log('Offer received','info');if(!peer)mkPeer();
    await peer.setRemoteDescription(new RTCSessionDescription(d.sdp));
    const ans=await peer.createAnswer();await peer.setLocalDescription(ans);send({type:'answer',sdp:peer.localDescription});log('Answer sent','ok');}
  else if(d.type==='ice'&&peer){try{await peer.addIceCandidate(new RTCIceCandidate(d.candidate));}catch(e){}}
  else if(d.type==='ptt-on'){dot('dPtt',true,'warn');ring('receiving','🔊 Client Speaking','PTT held');log('PTT ON','info');}
  else if(d.type==='ptt-off'){dot('dPtt',false);ring('talking','Connected','Mic live');log('PTT OFF','info');}
  else if(d.type==='client-ready'){log('Client connected','info');}
}
connect();
</script>
</body>
</html>
HTMLEOF

# ── Write client.html ─────────────────────────────────────
cat > public/client.html << CLIENTEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SMS IoT - Client PTT</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:'Segoe UI',sans-serif;background:#0f1117;color:#e0e0e0;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;user-select:none}
  .card{background:#1a1d27;border:1px solid #2a2d3a;border-radius:16px;padding:40px;text-align:center;width:340px}
  h1{font-size:20px;color:#fff;margin-bottom:6px}
  .sub{font-size:13px;color:#666;margin-bottom:30px}
  .btn{width:150px;height:150px;border-radius:50%;border:none;cursor:pointer;font-size:50px;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;transition:all 0.15s;-webkit-tap-highlight-color:transparent;touch-action:none}
  .btn.idle{border:3px solid #333;background:#1e2130}
  .btn.ready{border:3px solid #22c55e;background:#0f2a1a;box-shadow:0 0 20px #22c55e44}
  .btn.active{border:3px solid #ef4444;background:#2a0f0f;box-shadow:0 0 40px #ef444488;transform:scale(0.95)}
  .btn:disabled{opacity:.4;cursor:not-allowed}
  .lbl{font-size:14px;color:#888;margin-bottom:6px;height:20px}
  .hint{font-size:11px;color:#444;margin-bottom:24px}
  .dots{display:flex;gap:12px;justify-content:center;margin-bottom:20px}
  .di{display:flex;align-items:center;gap:6px;font-size:12px;color:#666}
  .dot{width:8px;height:8px;border-radius:50%;background:#333;transition:all .3s}
  .dot.on{background:#22c55e;box-shadow:0 0 6px #22c55e}
  .dot.warn{background:#ef4444;box-shadow:0 0 6px #ef4444}
  .dot.blue{background:#3b82f6;box-shadow:0 0 6px #3b82f6}
  .log{background:#0f1117;border-radius:8px;padding:10px;font-size:11px;color:#555;text-align:left;max-height:90px;overflow-y:auto;font-family:monospace}
  .log .ok{color:#22c55e}.log .info{color:#3b82f6}.log .warn{color:#f59e0b}
  audio{display:none}
</style>
</head>
<body>
<div class="card">
  <h1>📱 Client PTT</h1>
  <p class="sub">Press and hold to speak</p>
  <button class="btn idle" id="btn" disabled>🎙️</button>
  <div class="lbl" id="lbl">Connecting...</div>
  <div class="hint" id="hint">Please wait</div>
  <div class="dots">
    <div class="di"><div class="dot" id="dMqtt"></div><span>MQTT</span></div>
    <div class="di"><div class="dot" id="dTower"></div><span>Tower</span></div>
    <div class="di"><div class="dot" id="dLink"></div><span>Link</span></div>
  </div>
  <div class="log" id="log"></div>
</div>
<audio id="remoteAudio" autoplay playsinline></audio>
<script src="https://cdnjs.cloudflare.com/ajax/libs/paho-mqtt/1.1.0/paho-mqtt.min.js"></script>
<script>
const MQTT_HOST='${MQTT_IP}', MQTT_PORT=9001, TOPIC='sms/webrtc/signal', ROLE='client';
let mqtt,peer,stream,ready=false,conn=false,ptt=false;
const btn=document.getElementById('btn');
function log(m,t=''){const e=document.getElementById('log'),d=document.createElement('div');d.className=t;d.textContent='['+new Date().toLocaleTimeString()+'] '+m;e.appendChild(d);e.scrollTop=e.scrollHeight;}
function dot(id,on,t='on'){document.getElementById(id).className='dot'+(on?' '+t:'');}
function setBtn(s,l,h){btn.className='btn '+s;document.getElementById('lbl').textContent=l;document.getElementById('hint').textContent=h;}
function send(d){if(!ready)return;const m=new Paho.Message(JSON.stringify({...d,from:ROLE}));m.destinationName=TOPIC;m.retained=false;mqtt.send(m);}
function connect(){
  mqtt=new Paho.Client(MQTT_HOST,MQTT_PORT,'sms-client-'+Date.now());
  mqtt.onConnectionLost=()=>{ready=false;dot('dMqtt',false);setBtn('idle','Reconnecting...','');btn.disabled=true;setTimeout(connect,3000);};
  mqtt.onMessageArrived=msg=>{try{const d=JSON.parse(msg.payloadString);if(d.from===ROLE)return;handle(d);}catch(e){}};
  mqtt.connect({onSuccess:()=>{ready=true;dot('dMqtt',true);log('MQTT connected','ok');mqtt.subscribe(TOPIC);send({type:'client-ready'});initMic();},
    onFailure:e=>{log('MQTT failed','warn');setTimeout(connect,3000);},keepAliveInterval:30,useSSL:false});
}
async function initMic(){
  try{stream=await navigator.mediaDevices.getUserMedia({audio:true,video:false});
    stream.getAudioTracks().forEach(t=>t.enabled=false);log('Mic ready','ok');call();}
  catch(e){log('Mic error: '+e.message,'warn');}
}
async function call(){
  if(peer)peer.close();
  peer=new RTCPeerConnection({iceServers:[{urls:'stun:stun.l.google.com:19302'}]});
  if(stream)stream.getTracks().forEach(t=>peer.addTrack(t,stream));
  peer.ontrack=e=>{document.getElementById('remoteAudio').srcObject=e.streams[0];log('Tower audio connected','ok');};
  peer.onicecandidate=e=>{if(e.candidate)send({type:'ice',candidate:e.candidate});};
  peer.onconnectionstatechange=()=>{const s=peer.connectionState;
    if(s==='connected'){conn=true;dot('dLink',true,'blue');setBtn('ready','Hold to Talk','Press and hold the button');btn.disabled=false;log('Connected to tower!','ok');}
    else if(s==='disconnected'||s==='failed'){conn=false;dot('dLink',false);dot('dTower',false);btn.disabled=true;setBtn('idle','Disconnected','Retrying...');setTimeout(call,5000);}};
  const offer=await peer.createOffer();await peer.setLocalDescription(offer);send({type:'offer',sdp:peer.localDescription});log('Offer sent...','info');
}
async function handle(d){
  if(d.type==='tower-ready'){dot('dTower',true);log('Tower online','ok');}
  else if(d.type==='answer'){await peer.setRemoteDescription(new RTCSessionDescription(d.sdp));log('Answer received','ok');}
  else if(d.type==='ice'&&peer){try{await peer.addIceCandidate(new RTCIceCandidate(d.candidate));}catch(e){}}
}
function pttOn(){if(!conn||!stream||ptt)return;ptt=true;stream.getAudioTracks().forEach(t=>t.enabled=true);setBtn('active','🔴 Transmitting','Release to stop');dot('dLink',true,'warn');send({type:'ptt-on'});log('PTT ON','info');}
function pttOff(){if(!ptt)return;ptt=false;stream.getAudioTracks().forEach(t=>t.enabled=false);setBtn('ready','Hold to Talk','Press and hold the button');dot('dLink',true,'blue');send({type:'ptt-off'});log('PTT OFF','info');}
btn.addEventListener('mousedown',pttOn);btn.addEventListener('mouseup',pttOff);btn.addEventListener('mouseleave',pttOff);
btn.addEventListener('touchstart',e=>{e.preventDefault();pttOn();},{passive:false});
btn.addEventListener('touchend',e=>{e.preventDefault();pttOff();},{passive:false});
document.addEventListener('keydown',e=>{if(e.code==='Space'&&!e.repeat){e.preventDefault();pttOn();}});
document.addEventListener('keyup',e=>{if(e.code==='Space'){e.preventDefault();pttOff();}});
connect();
</script>
</body>
</html>
CLIENTEOF

curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/-sms-ptt/main/public/tower.html -o public/tower.html
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/-sms-ptt/main/public/client.html -o public/client.html
log "HTML files written"

# ── npm install ───────────────────────────────────────────
info "Installing Node dependencies..."
npm install --silent
log "Node dependencies installed"

# ── Write start-tower.sh ──────────────────────────────────
cat > start-tower.sh << 'STARTEOF'
#!/bin/bash
pkill -f "Xvfb :99" 2>/dev/null || true
pkill -f chromium 2>/dev/null || true
sleep 1

Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
sleep 2

# Set USB mic as default if available
USB_SOURCE=$(pactl list sources short 2>/dev/null | grep -i usb | awk '{print $2}' | head -1)
[ -n "$USB_SOURCE" ] && pactl set-default-source "$USB_SOURCE" && echo "Mic set: $USB_SOURCE"

chromium-browser \
  --display=:99 \
  --no-sandbox \
  --disable-dev-shm-usage \
  --autoplay-policy=no-user-gesture-required \
  --use-fake-ui-for-media-stream \
  --disable-infobars \
  --app=http://localhost:8090/tower.html &

echo "Tower browser started"
STARTEOF
chmod +x start-tower.sh

# ── systemd: ptt-server ───────────────────────────────────
info "Setting up systemd services..."
sudo tee /etc/systemd/system/ptt-server.service > /dev/null << SVCEOF
[Unit]
Description=SMS IoT PTT Server
After=network.target

[Service]
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
User=${USER}

[Install]
WantedBy=multi-user.target
SVCEOF

# ── systemd: ptt-tower ────────────────────────────────────
sudo tee /etc/systemd/system/ptt-tower.service > /dev/null << SVCEOF
[Unit]
Description=SMS IoT PTT Tower Browser
After=network.target ptt-server.service
Wants=ptt-server.service

[Service]
WorkingDirectory=${INSTALL_DIR}
ExecStart=/bin/bash ${INSTALL_DIR}/start-tower.sh
Restart=always
RestartSec=10
User=${USER}
Environment=HOME=/home/${USER}

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable --now ptt-server
sudo systemctl enable --now ptt-tower

log "Services enabled and started"

# ── Final status ──────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Tower Setup Complete!                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
log "MQTT broker   : $MQTT_IP:1883"
log "Tower IP      : $TOWER_IP"
log "Tower page    : http://$TOWER_IP:8090/tower.html"
log "Client page   : http://$TOWER_IP:8090/client.html"
echo ""
info "Service status:"
sudo systemctl status ptt-server --no-pager -l | grep -E "Active|Error" || true
sudo systemctl status ptt-tower  --no-pager -l | grep -E "Active|Error" || true
echo ""
log "Done! Tower will auto-start on every reboot."
