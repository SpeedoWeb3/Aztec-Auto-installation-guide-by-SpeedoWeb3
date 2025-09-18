#!/bin/bash
set -u   # safer: exit on unset vars only

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

show_header() {
  clear
  echo -e "${CYAN}==============================================================="
  echo "                     🚀 AZTEC NODE GUIDE 🚀"
  echo "               Script made by SpeedoWeb3 with ♥️"
  echo -e "===============================================================${NC}"
}

install_aztec_node() {
    echo -e "${CYAN}Starting Full Aztec Node Installation...${NC}"

    # Step 1: Root access check
    sudo sh -c 'echo "• Root Access Enabled ✔"'

    # Step 2: Update system
    sudo apt-get update && sudo apt-get upgrade -y

    # Step 3: Install prerequisites
    sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
      automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
      tar clang bsdmainutils ncdu unzip ufw screen gawk netcat-openbsd

    # Step 4: Install Docker (safe cleanup only for Aztec)
    if [ ! -f /etc/os-release ]; then echo "Not Ubuntu or Debian"; exit 1; fi

    echo -e "${CYAN}Checking for existing Aztec Docker containers/images...${NC}"
    AZTEC_CONTAINERS=$(docker ps -a --filter "ancestor=aztecprotocol/aztec" --format "{{.ID}}")
    AZTEC_IMAGES=$(docker images aztecprotocol/aztec -q)

    if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_IMAGES" ]; then
      echo -e "${RED}⚠️ Existing Aztec Docker setup detected!${NC}"
      echo "Containers: $AZTEC_CONTAINERS"
      echo "Images: $AZTEC_IMAGES"
      read -p "➡ Do you want to delete and reinstall Aztec? (Y/n): " del_choice
      if [[ ! "$del_choice" =~ ^[Yy]$ && -n "$del_choice" ]]; then
        echo "❌ Installation cancelled."; return
      fi
      docker stop $AZTEC_CONTAINERS 2>/dev/null || true
      docker rm $AZTEC_CONTAINERS 2>/dev/null || true
      docker rmi $AZTEC_IMAGES 2>/dev/null || true
      echo "✅ Old Aztec Docker setup removed."
    fi

    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    . /etc/os-release
    curl -fsSL "https://download.docker.com/linux/$ID/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl restart docker
    echo -e "${CYAN}• Docker Installed ✔${NC}"

    # Step 5: Firewall
    sudo apt install -y ufw >/dev/null 2>&1
    sudo ufw allow 22
    sudo ufw allow ssh
    sudo ufw allow 40400/tcp
    sudo ufw allow 40400/udp
    sudo ufw allow 8080
    sudo ufw reload
    sudo ufw --force enable

    # Step 6: Setup directory
    rm -rf ~/aztec && mkdir ~/aztec && cd ~/aztec

    # Step 7: Ask user for details and create .env
    echo -e "${CYAN}Let's configure your node...${NC}"
    read -p "➡ Enter Sepolia RPC URL: " ETH_RPC
    read -p "➡ Enter Beacon RPC URL: " BEACON_RPC
    read -p "➡ Enter Validator Private Key (0x...): " VAL_PRIV
    read -p "➡ Enter Wallet Address (0x...): " WALLET_ADDR
    VPS_IP=$(curl -s ipv4.icanhazip.com)
    echo "➡ Auto-detected VPS IP: $VPS_IP"

    cat > .env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF

    echo -e "${CYAN}.env file created successfully ✅${NC}"
    cat .env

    # Step 8: Create docker-compose.yml
    cat > docker-compose.yml <<'EOF'
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:2.0.2
    restart: unless-stopped
    network_mode: host
    environment:
      ETHEREUM_HOSTS: ${ETHEREUM_RPC_URL}
      L1_CONSENSUS_HOST_URLS: ${CONSENSUS_BEACON_URL}
      DATA_DIRECTORY: /data
      VALIDATOR_PRIVATE_KEYS: ${VALIDATOR_PRIVATE_KEYS}
      COINBASE: ${COINBASE}
      P2P_IP: ${P2P_IP}
      LOG_LEVEL: info
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - ${HOME}/.aztec/testnet/data/:/data
EOF

    # Step 9: Snapshot restore (optional)
    echo "--- Downloading snapshot..."
    wget -O $HOME/aztec-testnet.tar.lz4 https://files5.blacknodes.net/aztec/aztec-testnet.tar.lz4 || echo "⚠️ Snapshot not found. Continuing without it..."
    if [ -f "$HOME/aztec-testnet.tar.lz4" ]; then
      lz4 -d $HOME/aztec-testnet.tar.lz4 | tar x -C $HOME/.aztec/testnet
      rm $HOME/aztec-testnet.tar.lz4
      echo "✅ Snapshot installed!"
    else
      echo "⚠️ Skipped snapshot (not available)."
    fi

    # Step 10: Start node
    docker compose -f ~/aztec/docker-compose.yml up -d
    echo -e "${CYAN}Installation finished 🚀 Use option 3 to view logs.${NC}"
}

check_rpc_health() {
  echo "--- Running RPC Health Check..."
  if [ -f "$HOME/aztec/.env" ]; then
    source "$HOME/aztec/.env"
    SEPOLIA_RPC=$ETHEREUM_RPC_URL
    BEACON_RPC=$CONSENSUS_BEACON_URL
  else
    echo "⚠️ .env not found. Please run Full Install first."; return
  fi

  echo "🔎 Checking Sepolia RPC: $SEPOLIA_RPC"
  curl -s --max-time 5 "$SEPOLIA_RPC" >/dev/null 2>&1 && echo "✅ Reachable" || echo "❌ Not reachable"

  echo "🔎 Checking Beacon RPC: $BEACON_RPC"
  curl -s --max-time 5 "$BEACON_RPC" >/dev/null 2>&1 && echo "✅ Reachable" || echo "❌ Not reachable"
}

check_ports_and_peerid() {
  echo "Checking important ports..."
  declare -A PORTS=( ["40400/tcp"]="Aztec P2P (TCP)" ["40400/udp"]="Aztec P2P (UDP)" ["8545/tcp"]="RPC" ["3500/tcp"]="Custom" )
  for p in "${!PORTS[@]}"; do
    proto=${p##*/}; port=${p%%/*}
    if nc -${proto:0:1} -z -w2 127.0.0.1 "$port" >/dev/null 2>&1; then
      echo "✅  Port $p (${PORTS[$p]}) is OPEN"
    else
      echo "❌  Port $p (${PORTS[$p]}) is CLOSED → Opening..."
      sudo ufw allow "$port/$proto" >/dev/null 2>&1
    fi
  done

  echo "--- Checking Peer ID..."
  PEER_ID=$(docker logs aztec-sequencer 2>&1 | grep -o '"peerId":"[^"]*"' | head -n 1 | awk -F':' '{print $2}' | tr -d '"')
  if [ -n "$PEER_ID" ]; then
    echo "✅ Peer ID: $PEER_ID"
    echo "🔗 Check it here: https://aztec.nethermind.io/explore"
  else
    echo "⚠️ Peer ID not found. Make sure your node is running."
  fi
}

# ───────────────────────────────────────────────
# Menu
# ───────────────────────────────────────────────
while true; do
  show_header
  echo -e "${CYAN}1) Full Install (with Snapshot)${NC}"
  echo -e "${CYAN}2) Run Node${NC}"
  echo -e "${CYAN}3) View Logs${NC}"
  echo -e "${CYAN}4) View & Reconfigure .env${NC}"
  echo -e "${CYAN}5) Check RPC Health${NC}"
  echo -e "${CYAN}6) Delete Node${NC}"
  echo -e "${CYAN}7) Check Ports & Peer ID${NC}"
  echo -e "${CYAN}8) Update Node${NC}"
  echo -e "${CYAN}9) Check Node Version${NC}"
  echo -e "${CYAN}10) Exit${NC}"
  echo ""
  read -p "Choose option (1-10): " choice

  case $choice in
    1) install_aztec_node ;;
    2) cd ~/aztec && docker compose up -d && docker compose logs -f ;;
    3) cd ~/aztec && docker compose logs -f ;;
    4) 
       echo "--- Current .env ---"
       cat ~/aztec/.env
       echo ""
       read -p "➡ Do you want to edit values? (Y/n): " edit_choice
       if [[ "$edit_choice" =~ ^[Yy]$ || -z "$edit_choice" ]]; then
         read -p "➡ Enter new Sepolia RPC URL: " ETH_RPC
         read -p "➡ Enter new Beacon RPC URL: " BEACON_RPC
         read -p "➡ Enter new Validator Private Key (0x...): " VAL_PRIV
         read -p "➡ Enter new Wallet Address (0x...): " WALLET_ADDR
         VPS_IP=$(curl -s ipv4.icanhazip.com)
         cat > ~/aztec/.env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF
         echo "✅ .env updated. Restarting node..."
         cd ~/aztec && docker compose up -d
       fi
       ;;
    5) check_rpc_health ;;
    6) docker stop aztec-sequencer 2>/dev/null; docker rm aztec-sequencer 2>/dev/null; rm -rf ~/aztec ~/.aztec/testnet; echo "✅ Node deleted." ;;
    7) check_ports_and_peerid ;;
    8) docker pull aztecprotocol/aztec:2.0.2 && (cd ~/aztec && docker compose up -d) ;;
    9) docker exec aztec-sequencer node /usr/src/yarn-project/aztec/dest/bin/index.js --version ;;
    10) echo "Exiting..."; break ;;
    *) echo "Invalid option" ;;
  esac

  read -p "Press Enter to continue..."
done
