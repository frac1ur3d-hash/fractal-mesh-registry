#!/usr/bin/env bash
# ==============================================================================
# ⚡ AETHER-EGO: 1-Click Universal VM Bootstrap & Mesh Check-In
# Target: Any Cloud VM / VPS / Container (Ubuntu, Debian, Oracle Linux, CentOS)
# ==============================================================================
set -e

REPO="frac1ur3d-hash/fractal-mesh-registry"
TS_AUTHKEY="${TS_AUTHKEY:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-$1}"
WORK_DIR="/opt/aether-mesh"

echo "================================================================================"
echo "⚡ Bootstrapping Fractal Support Node into Mesh Network..."
echo "================================================================================"

# 1. Ensure Tailscale is installed & joined
if ! command -v tailscale &> /dev/null; then
    echo "[*] Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! tailscale status &> /dev/null; then
    echo "[*] Joining Tailscale Mesh..."
    sudo tailscale up --authkey="${TS_AUTHKEY}" --hostname="aether-vm-$(hostname)" --accept-routes || true
fi

TS_IP=$(tailscale ip -4 2>/dev/null || echo "pending")
echo "[+] Mesh IP: ${TS_IP}"

# 2. Setup Work Directory (RAM-Disk if diskless or /opt)
if [ -d "/dev/shm" ] && [ -w "/dev/shm" ]; then
    WORK_DIR="/dev/shm/aether-mesh"
    echo "[*] Diskless/RAM-Disk Environment detected: running 100% in volatile RAM (${WORK_DIR})"
else
    WORK_DIR="/opt/aether-mesh"
    echo "[*] Preparing Node Runtime in ${WORK_DIR}..."
fi

mkdir -p "${WORK_DIR}" 2>/dev/null || sudo mkdir -p "${WORK_DIR}"
sudo chown -R $(whoami) "${WORK_DIR}" 2>/dev/null || true
cd "${WORK_DIR}"

if ! command -v python3 &> /dev/null; then
    echo "[*] Installing Python 3..."
    sudo apt-get update -y && sudo apt-get install -y python3 curl || sudo yum install -y python3 curl
fi

# 3. Fetch Standalone Node Engine from GitHub
echo "[*] Pulling latest universal node engine from GitHub..."
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/aether_node.py" -o aether_node.py
chmod +x aether_node.py

# 4. Generate local node_config.json
NODE_ID="node-vm-$(hostname | tr '[:upper:]' '[:lower:]')"
mkdir -p config
cat << EOF > config/node_config.json
{
  "node_id": "${NODE_ID}",
  "role": "support",
  "platform": "linux",
  "github_token": "${GITHUB_TOKEN}",
  "mesh_network": {
    "tailscale_ip": "${TS_IP}",
    "peer_nodes": [
      {
        "node_id": "node-n0n3yob1z",
        "role": "root",
        "tailscale_ip": "100.116.147.94"
      }
    ]
  },
  "heartbeat_interval_seconds": 60,
  "autonomy_level": 2,
  "dense_protocol_version": "1.0-MNDCP"
}
EOF

# 5. Execute Initial Check-in Tick & Start Daemon
echo "[*] Executing initial node registration check-in to GitHub..."
python3 aether_node.py --single-tick

echo "[*] Launching Fractal Node Daemon in background..."
nohup python3 aether_node.py --daemon > logs_daemon.log 2>&1 &
PID=$!
echo "[✓] Node [${NODE_ID}] is online and checking in to GitHub every 60s (PID: ${PID})!"
echo "    Log file: ${WORK_DIR}/logs_daemon.log"
echo "================================================================================"
