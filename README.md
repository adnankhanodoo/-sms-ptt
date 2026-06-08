# SMS IoT PTT System
## WebRTC Push-to-Talk over MQTT

Zero new infrastructure — uses your existing Mosquitto MQTT broker.

---

## Architecture

```
[Tower Machine - headless]         [Client Machine - browser]
  USB Mic always on                  PTT button in browser
  Chrome hidden (Xvfb)               Press = talk to tower
  Streams audio 24/7                 Hears tower always
       |                                    |
       └──────── WebRTC audio ──────────────┘
                      |
              MQTT signaling
          (your existing broker)
```

---

## Setup — 3 steps

### Step 1 — MQTT WebSocket (run on broker machine once)
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/sms-ptt/main/setup-mqtt-ws.sh | bash
```

### Step 2 — Tower machine (headless, no monitor)
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/sms-ptt/main/install-tower.sh | bash -s -- <MQTT_BROKER_IP>
```
Example:
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/sms-ptt/main/install-tower.sh | bash -s -- 100.84.208.88
```

### Step 3 — Client machine (with browser)
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/sms-ptt/main/install-client.sh | bash -s -- <TOWER_IP>
```
Example:
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/sms-ptt/main/install-client.sh | bash -s -- 100.84.108.142
```

---

## What gets installed

### Tower machine
- Node.js server (port 8090)
- Xvfb virtual display
- PulseAudio
- Chromium (headless, hidden)
- 2 systemd services (auto-start on boot)

### Client machine  
- Desktop shortcut only
- Opens browser to tower URL

---

## Ports used

| Port | Purpose | Conflicts? |
|------|---------|------------|
| 8090 | PTT web server | New — no conflict |
| 9001 | Mosquitto WebSocket | Added to existing |
| 1883 | Mosquitto MQTT | Already exists |

---

## After reboot

Tower auto-starts. Client just opens browser:
```
http://<TOWER_IP>:8090/client.html
```

---

## Troubleshoot

```bash
# Tower logs
sudo journalctl -u ptt-server -f
sudo journalctl -u ptt-tower -f

# Restart
sudo systemctl restart ptt-server ptt-tower

# Check health
curl http://localhost:8090/health
```
