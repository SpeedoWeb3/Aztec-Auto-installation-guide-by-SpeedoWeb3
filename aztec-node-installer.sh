#!/bin/bash
set -u   # safer: exit on unset vars only

CYAN='\033[0;36m'
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

    # Step 4: Install Docker
    if [ ! -f /etc/os-release ]; then echo "Not Ubuntu or Debian"; exit 1; fi
    sudo apt update -y && sudo apt upgrade -y
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin; do
      sudo apt-get remove --purge -y "$pkg" 2>/dev/null || true
    done
    sudo apt-get autoremove -y
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
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

    # Step 6: Cleanup old Aztec
    bash <(curl -Ls "https://raw.githubusercontent.com/DeepPatel2412/Aztec-Tools/main/Aztec%20CLI%20Cleanup") || true

    # Step 7: Setup directory
    rm -rf ~/aztec && mkdir ~/aztec && cd ~/aztec

    # Step 8: Ask user for details and create .env
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

    # Step 9: Create docker-compose.yml
    cat > docker-compose.yml <<'EOF'
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:1.2.1
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
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - ${HOME}/.aztec/alpha-testnet/data/:/data
EOF

    # Step 10: Snapshot restore
    echo "--- Stopping the Aztec node to prevent data corruption..."
    docker stop aztec-sequencer 2>/dev/null || true
    docker rm   aztec-sequencer 2>/dev/null || true

    echo "--- Installing lz4 (required for extraction)..."
    sudo apt-get install -y lz4

    echo "--- Deleting old node data..."
    rm -rf $HOME/.aztec/alpha-testnet/data

    echo "--- Creating directory structure..."
    mkdir -p $HOME/.aztec/alpha-testnet

    echo "--- Downloading snapshot..."
    wget -O $HOME/aztec-alpha-testnet.tar.lz4 https://files5.blacknodes.net/aztec/aztec-alpha-testnet.tar.lz4

    echo "--- Extracting snapshot..."
    lz4 -d $HOME/aztec-alpha-testnet.tar.lz4 | tar x -C $HOME/.aztec/alpha-testnet

    echo "--- Cleaning up snapshot file..."
    rm $HOME/aztec-alpha-testnet.tar.lz4

    echo "✅ Snapshot successfully installed!"

    # Step 11: Start node
    docker compose -f ~/aztec/docker-compose.yml up -d
    echo -e "${CYAN}Installation finished 🚀 Use option 3 to view logs.${NC}"
}

check_rpc_health() {
  echo "--- Running RPC Health Check (with Catman Creed's guide)..."
  read -p "➡ Do you want to use RPCs from .env automatically? (Y/n): " auto_choice
  if [[ "$auto_choice" =~ ^[Yy]$ || -z "$auto_choice" ]]; then
    if [ -f "$HOME/aztec/.env" ]; then
      source "$HOME/aztec/.env"
      SEPOLIA_RPC=$ETHEREUM_RPC_URL
      BEACON_RPC=$CONSENSUS_BEACON_URL
    else
      echo "⚠️ .env not found. Please run Full Install first."
      return
    fi
  else
    read -p "➡ Enter custom Sepolia RPC URL: " SEPOLIA_RPC
    read -p "➡ Enter custom Beacon RPC URL: " BEACON_RPC
  fi

  echo ""
  echo "🔎 Checking Sepolia RPC: $SEPOLIA_RPC"
  if curl -s --max-time 5 "$SEPOLIA_RPC" >/dev/null 2>&1; then
    echo "✅ Sepolia RPC is reachable"
  else
    echo "❌ Sepolia RPC is not reachable"
  fi

  echo ""
  echo "🔎 Checking Beacon RPC: $BEACON_RPC"
  if curl -s --max-time 5 "$BEACON_RPC" >/dev/null 2>&1; then
    echo "✅ Beacon RPC is reachable"
  else
    echo "❌ Beacon RPC is not reachable"
  fi

  echo ""
  echo "📖 For advanced diagnostics (Catman Creed’s guide), see:"
  echo "🔗 https://raw.githubusercontent.com/DeepPatel2412/Aztec-Tools/main/RPC%20Health%20Check"
}

check_ports_and_peerid() {
  echo "Checking important ports..."
  declare -A PORTS=( ["40400/tcp"]="Aztec P2P (TCP)" ["40400/udp"]="Aztec P2P (UDP)" ["8545/tcp"]="RPC" ["3500/tcp"]="Custom" )
  for p in "${!PORTS[@]}"; do
    proto=${p##*/}; port=${p%%/*}
    if nc -${proto:0:1} -z -w2 127.0.0.1 "$port" >/dev/null 2>&1; then
      echo "✅  Port $p (${PORTS[$p]}) is OPEN"
    else
      echo "❌  Port $p (${PORTS[$p]}) is CLOSED → Opening with ufw..."
      sudo ufw allow "$port/$proto" >/dev/null 2>&1
      sleep 1
    fi
  done

  echo ""
  echo "--- Checking Peer ID from logs..."
  PEER_ID=$(sudo bash -c "docker logs \$(docker ps -q --filter ancestor=aztecprotocol/aztec:1.2.1 | head -n 1) 2>&1 | grep -i peerId | grep -o '\"peerId\":\"[^\"]*\"' | cut -d'\"' -f4 | head -n 1")
  if [ -n "$PEER_ID" ]; then
    echo "✅ Peer ID: $PEER_ID"
  else
    echo "⚠️ Peer ID not found. Make sure your node is running."
  fi
  echo "🔗 Check it here: https://aztec.nethermind.io/explore"
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
  echo -e "${CYAN}5) Check RPC Health (with Catman Creed's guide)${NC}"
  echo -e "${CYAN}6) Delete Node${NC}"
  echo -e "${CYAN}7) Check Ports & Peer ID${NC}"
  echo -e "${CYAN}8) Update Node${NC}"
  echo -e "${CYAN}9) Exit${NC}"
  echo ""
  read -p "Choose option (1-9): " choice

  case $choice in
    1) install_aztec_node ;;
    2) cd ~/aztec && docker compose up -d && docker compose logs -f ;;
    3) cd ~/aztec && docker compose logs -f ;;
    4) 
       echo "--- Viewing current .env ---"
       if [ -f "$HOME/aztec/.env" ]; then
         cat "$HOME/aztec/.env"
         echo ""
         read -p "➡ Do you want to edit and reconfigure? (Y/n): " edit_choice
         if [[ "$edit_choice" =~ ^[Yy]$ || -z "$edit_choice" ]]; then
           read -p "➡ Enter new Sepolia RPC URL: " ETH_RPC
           read -p "➡ Enter new Beacon RPC URL: " BEACON_RPC
           read -p "➡ Enter new Validator Private Key (0x...): " VAL_PRIV
           read -p "➡ Enter new Wallet Address (0x...): " WALLET_ADDR
           VPS_IP=$(curl -s ipv4.icanhazip.com)
           cat > $HOME/aztec/.env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF
           echo "✅ .env updated. Restarting node..."
           cd ~/aztec && docker compose up -d
         fi
       else
         echo "⚠️ .env not found. Run Full Install first."
       fi
       ;;
    5) check_rpc_health ;;
    6) echo "⚠️ Delete Node will affect these paths:"; echo "   - $HOME/aztec"; echo "   - $HOME/.aztec/alpha-testnet"; echo "   - Docker container: aztec-sequencer"; echo ""; read -p "➡ Do you want to continue? (Y/n): " confirm; if [[ "$confirm" =~ ^[Yy]$ || -z "$confirm" ]]; then read -p "➡ Are you REALLY sure you want to delete these? (Y/n): " confirm2; if [[ "$confirm2" =~ ^[Yy]$ || -z "$confirm2" ]]; then docker stop aztec-sequencer 2>/dev/null || true; docker rm aztec-sequencer 2>/dev/null || true; rm -rf "$HOME/aztec"; sudo rm -rf "$HOME/.aztec/alpha-testnet"; echo "✅ Aztec Node deleted."; else echo "❌ Second confirmation failed."; fi; else echo "❌ Delete cancelled."; fi ;;
    7) check_ports_and_peerid ;;
    8) docker pull aztecprotocol/aztec:1.2.1 && (cd ~/aztec && docker compose up -d) ;;
    9) echo -e "${CYAN}Exiting...${NC}"; break ;;
    *) echo "Invalid option" ;;
  esac

  read -p "Press Enter to continue..."
done
