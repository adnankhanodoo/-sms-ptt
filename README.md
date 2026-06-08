# SMS IoT PTT System
## Push-to-Talk: Client speaks → Tower hears

Simple, lightweight, low-latency. No WebRTC. No ICE negotiation. Just WebSocket + PCM audio.

---

## Architecture

```
[Client Browser]          [Tower Machine]
  Press PTT button    →    Node.js server
  Mic → PCM audio     →    Speaker plays
  WebSocket stream    →    Instant playback
```

---

## Requirements

### Tower machine
- Ubuntu Linux
- USB microphone (optional — tower receives audio)
- Speaker/headphone output
- Node.js 18+
- NetBird VPN (for remote access)

### Client machine
- Any browser (Chrome recommended)
- Microphone
- Access to tower IP

---

## Setup — 2 steps only

### Step 1 — Tower machine
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/-sms-ptt/main/install-tower.sh | bash
```

### Step 2 — Client machine
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/-sms-ptt/main/install-client.sh | bash -s -- <TOWER_IP>
```

Example:
```bash
curl -fsSL https://raw.githubusercontent.com/adnankhanodoo/-sms-ptt/main/install-client.sh | bash -s -- 100.84.108.142
```

---

## Usage

1. Tower server starts automatically on boot
2. Client opens browser: `http://<TOWER_IP>:8090`
3. Allow microphone permission
4. Press and hold PTT button to speak
5. Tower plays your voice instantly

---

## Ports

| Port | Purpose |
|------|---------|
| 8090 | PTT web server + WebSocket |

---

## Troubleshoot

```bash
# Check service status
systemctl --user status sms-ptt-tower

# Restart
systemctl --user restart sms-ptt-tower

# View logs
journalctl --user -u sms-ptt-tower -f
```
