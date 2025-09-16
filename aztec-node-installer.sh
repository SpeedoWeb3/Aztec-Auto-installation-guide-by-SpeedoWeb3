# Aztec-Auto-installation-guide-by-SpeedoWeb3
#!/bin/bash
set -e

CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔧 Starting Aztec Node Installation...${NC}"

# === Root Access Echo ===
sudo sh -c 'echo "• Root Access Enabled ✔"'

# === System Requirements Check ===
echo -e "${CYAN}🧠 Checking system specs...${NC}"
MIN_RAM=16000000      # 16 GB in KB
MIN_CORES=4
MIN_DISK=150           # 150 GB

RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
CORES=$(nproc)
DISK=$(df / --output=avail -BG | tail -1 | tr -dc '0-9')

if [ "$RAM" -lt "$MIN_RAM" ]; then
  echo -e "${CYAN}❌ Insufficient RAM: $(($RAM / 1024)) MB. Minimum required: 16 GB.${NC}"
  exit 1
fi

if [ "$CORES" -lt "$MIN_CORES" ]; then
  echo -e "${CYAN}❌ Insufficient CPU cores: $CORES. Minimum required: 4 cores.${NC}"
  exit 1
fi

if [ "$DISK" -lt "$MIN_DISK" ]; then
  echo -e "${CYAN}❌ Insufficient disk space: ${DISK} GB available. Minimum required: 150 GB.${NC}"
  exit 1
fi

echo -e "${CYAN}✅ System specs validated: $((RAM / 1024)) MB RAM, $CORES cores, $DISK GB disk.${NC}"

# === Docker Container Check ===
if docker ps --format '{{.Names}}' | grep -q aztec-sequencer; then
  echo -e "${CYAN}⚠️  Aztec sequencer container is already running.${NC}"
  read -p "Do you want to reinstall it? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    read -p "Do you want to stop and remove the existing container? (y/n): " clean
    if [[ "$clean" =~ ^[Yy]$ ]]; then
      docker stop aztec-sequencer && docker rm aztec-sequencer
      echo -e "${CYAN}✅ Container removed. Data preserved unless manually deleted.${NC}"
    else
      echo -e "${CYAN}🔄 Keeping existing container. Proceeding with config update only.${NC}"
    fi
  else
    echo -e "${CYAN}❌ Installation aborted by user.${NC}"
    exit 0
  fi
fi

# === Create Working Directory ===
mkdir -p aztec && cd aztec
echo "📁 Directory Ready ✓"
echo "📂 Changed Directory ✓"

# === Interactive .env Setup ===
echo -e "${CYAN}📄 Let's configure your Aztec node environment...${NC}"
read -p "🔗 Submit Sepolia RPC URL: " ETHEREUM_RPC_URL
read -p "🛰️  Submit Beacon RPC URL: " CONSENSUS_BEACON_URL
read -p "🔐 Submit Validator Private Key: " VALIDATOR_PRIVATE_KEYS
read -p "👛 Submit Coinbase Wallet Address: " COINBASE
P2P_IP=$(curl -s ipv4.icanhazip.com)
echo -e "🌐 Auto-detected Public IP: $P2P_IP"

cat <<EOF > .env
ETHEREUM_RPC_URL=$ETHEREUM_RPC_URL
CONSENSUS_BEACON_URL=$CONSENSUS_BEACON_URL
VALIDATOR_PRIVATE_KEYS=$VALIDATOR_PRIVATE_KEYS
COINBASE=$COINBASE
P2P_IP=$P2P_IP
EOF

echo -e "${CYAN}✅ .env file created.${NC}"

# === Validate .env ===
echo -e "${CYAN}🔍 Validating .env configuration...${NC}"
source .env

for var in ETHEREUM_RPC_URL CONSENSUS_BEACON_URL VALIDATOR_PRIVATE_KEYS COINBASE P2P_IP; do
  if [ -z "${!var}" ]; then
    echo -e "${CYAN}❌ $var is missing. Please re-run the installer.${NC}"
    exit 1
  fi
done

for url in "$ETHEREUM_RPC_URL" "$CONSENSUS_BEACON_URL"; do
  if ! [[ "$url" =~ ^https?:// ]]; then
    echo -e "${CYAN}❌ Invalid RPC URL format: $url${NC}"
    exit 1
  fi
  if ! curl -s --head "$url" | grep -q "200 OK"; then
    echo -e "${CYAN}❌ RPC URL not reachable: $url${NC}"
    exit 1
  fi
done

if ! [[ "$COINBASE" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  echo -e "${CYAN}❌ Invalid wallet address: $COINBASE${NC}"
  exit 1
fi

echo -e "${CYAN}✅ .env validation passed.${NC}"

# === Create docker-compose.yml ===
cat <<EOF > docker-compose.yml
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:1.2.1
    restart: unless-stopped
    network_mode: host
    environment:
      ETHEREUM_HOSTS: \${ETHEREUM_RPC_URL}
      L1_CONSENSUS_HOST_URLS: \${CONSENSUS_BEACON_URL}
      DATA_DIRECTORY: /data
      VALIDATOR_PRIVATE_KEYS: \${VALIDATOR_PRIVATE_KEYS}
      COINBASE: \${COINBASE}
      P2P_IP: \${P2P_IP}
      LOG_LEVEL: info
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - /root/.aztec/alpha-testnet/data/:/data
EOF

echo -e "${CYAN}📦 docker-compose.yml created.${NC}"

# === Final Launch Prompt ===
read -p "🚀 Ready to launch Aztec node? (y/n): " launch
if [[ "$launch" =~ ^[Yy]$ ]]; then
  docker compose up -d
  echo -e "${CYAN}✅ Aztec Node is now running in the background.${NC}"
else
  echo -e "${CYAN}🛑 Launch skipped by user.${NC}"
fi
