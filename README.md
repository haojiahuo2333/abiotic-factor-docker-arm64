# abiotic-factor-docker-arm64

> 🧪 Abiotic Factor Dedicated Server on ARM64 using Docker + Wine + box64/box86

This project provides a **Dockerized Abiotic Factor dedicated server** for **ARM64** platforms  
(e.g. Raspberry Pi 5, ARM-based Ubuntu servers), by running the **Windows dedicated server** under:

- Debian `bookworm` ARM64 base image  
- `box64` + `box86` (to emulate x86/x64 binaries)  
- `wine-stable` (to run the Windows server)  
- `steamcmd` (to auto-install / update server)  
- Optional `frp` reverse proxy to expose the server to the public internet

---

## 📁 Project Structure

Recommended repository layout:

```text
.
├── Dockerfile
├── docker-compose.yml
├── scripts/
│   ├── init-server.sh      # Entry point: steamcmd update + start server
│   └── healthz.sh          # Health check: ports + save freshness
└── data/
    └── abiotic/
        └── server/         # (created automatically via bind mount)
```

> `data/abiotic/server` is the host directory bound to `/abiotic/server` in the container  
> All Abiotic Factor dedicated server files and saves will live there.



---

## 🚀 Quick Start (LAN Only without Public IPv4？)

### 1. Clone this repository

```bash
git clone https://github.com/haojiahuo2333/abiotic-factor-docker-arm64.git
cd abiotic-factor-docker-arm64
```

### 2. Prepare data directory

```bash
mkdir -p ./data/abiotic/server
# Make sure Docker's steam user (UID 1001 by default) can write:
sudo chown -R 1001:1001 ./data/abiotic/server
```

> You can change UID/GID via build args, see below.

### 3. `docker-compose.yml` example

```yaml
services:
  abiotic-factor:
    build:
      context: .
      dockerfile: ARM64.Dockerfile
    container_name: abiotic-factor
    restart: unless-stopped

    environment:
      AF_SERVER_NAME: "My Abiotic Server"
      AF_SERVER_PASSWORD: "changeme"   # empty = no password
      AF_WORLD_NAME: "Cascade"         # world save name
      AF_MAX_PLAYERS: "6"

      AF_GAME_PORT: "7777"
      AF_QUERY_PORT: "27015"
      AF_SAVE_INTERVAL: "300"          # seconds between autosaves (approx.)

    ports:
      - "7777:7777/udp"
      - "27015:27015/udp"

    volumes:
      - ./data/abiotic/server:/abiotic/server
      # - ./data/abiotic/worlds:/abiotic/server/AbioticFactor/Saved/SaveGames/Server/Worlds

```

### 4. Build & start

```bash
docker compose build
docker compose up -d
```

### 5. Check logs

```bash
docker compose logs -f abiotic-factor
```

### 6. Connect from a client (LAN)

On a client in the **same LAN**:

- Direct IP connect:
  - Address: `your-ip`
  - Password: whatever you set in `AF_SERVER_PASSWORD`

---

## ⚙ Configuration

### Environment Variables

| Variable             | Default      | Description                                                                 |
|----------------------|-------------|-----------------------------------------------------------------------------|
| `AF_SERVER_NAME`     | `"AbioticFactorDocker"` | Server name shown in server browser / lobby                           |
| `AF_SERVER_PASSWORD` | `""`        | Server password. Empty = no password                                       |
| `AF_WORLD_NAME`      | `"Cascade"` | World save name (folder name under `Worlds/`)                              |
| `AF_MAX_PLAYERS`     | `"6"`       | Maximum number of players                                                  |
| `AF_GAME_PORT`       | `"7777"`    | Game UDP port                                                              |
| `AF_QUERY_PORT`      | `"27015"`   | Query UDP port                                                             |
| `AF_SAVE_INTERVAL`   | `"300"`     | Expected autosave interval (seconds). Used by health check script          |
|                      |                         |                                                              |

### Volumes

| Host path                    | Container path       | Description                             |
|-----------------------------|----------------------|-----------------------------------------|
| `./data/abiotic/server`     | `/abiotic/server`    | Full dedicated server installation + saves |

---

## 🩺 Health Check

The container includes a `HEALTHCHECK` using `scripts/healthz.sh`:

1. Checks UDP ports:
   - `AF_GAME_PORT` (default 7777)
   - `AF_QUERY_PORT` (default 27015)
2. Checks last modified time of save files in:
   - `/abiotic/server/AbioticFactor/Saved/SaveGames/Server/Worlds/<AF_WORLD_NAME>`

If **no save files** have been updated within:

> `AF_SAVE_INTERVAL + 180` seconds

the health check fails and Docker marks the container as `unhealthy`.

This helps detect “server is frozen / not autosaving anymore” situations.

---

## 🌍 Public Internet Access / FRP

### ❗ Without public IPv4 / port forwarding:

- Only clients in the **same LAN** can connect via `IP:PORT`
- Other players on the internet **cannot** connect directly

### ✅ With FRP reverse proxy (UDP) + cloud server:

You can use **frp** (fast reverse proxy) with a public cloud server to expose your home / LAN server to the internet.

**Basic idea:**

- Cloud server (with public IP) runs `frps` (server)
- Raspberry Pi runs `frpc` (client), forwarding:
  - UDP 7777 (game)
  - UDP 27015 (query)
- Players connect to **cloud server's public IP:7777**

#### Example `frps.ini` (on cloud server)

```ini
[common]
bind_port = 7000
token = your-strong-token
udp_packet_size = 1500
```

Run:

```bash
./frps -c frps.ini
```

#### Example `frpc.ini` (on Raspberry Pi)

```ini
[common]
server_addr = <YOUR_CLOUD_SERVER_IP>
server_port = 7000
token = your-strong-token

[abiotic_udp]
type = udp
local_ip = 127.0.0.1
local_port = 7777
remote_port = 7777

[abiotic_query]
type = udp
local_ip = 127.0.0.1
local_port = 27015
remote_port = 27015
```

Start:

```bash
./frpc -c frpc.ini
```

---

## 🧪 Debugging Tips

- View server logs:

  ```bash
  docker compose logs -f abiotic-factor
  ```

