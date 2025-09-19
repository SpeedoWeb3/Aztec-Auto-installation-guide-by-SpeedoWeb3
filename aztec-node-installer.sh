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
    AZTEC_CONTAINERS=$(sudo docker ps -a --filter "ancestor=aztecprotocol/aztec" --format "{{.Names}}")
    AZTEC_IMAGES=$(sudo docker images aztecprotocol/aztec -q)

    if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_IMAGES" ]; then
      echo -e "${RED}⚠️ Existing Aztec Docker setup detected!${NC}"
      echo "Containers: ${AZTEC_CONTAINERS:-None}"
      echo "Images: ${AZTEC_IMAGES:-None}"
      read -p "➡ Do you want to delete and reinstall Aztec only? (Y/n): " del_choice
      if [[ ! "$del_choice" =~ ^[Yy]$ && -n "$del_choice" ]]; then
        echo "❌ Installation cancelled."; return
      fi
      [ -n "$AZTEC_CONTAINERS" ] && sudo docker stop $AZTEC_CONTAINERS && sudo docker rm $AZTEC_CONTAINERS
      [ -n "$AZTEC_IMAGES" ] && sudo docker rmi $AZTEC_IMAGES
      echo "✅ Old Aztec Docker setup removed."
    fi

    # Docker installation
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

    # Fix Docker permission denied issue
    sudo usermod -aG docker $USER
    echo "✅ User added to docker group. Please log out and log back in (or run 'exec su - $USER') for changes to take effect."

    # Step 5: Firewall
    sudo apt install -y ufw >/dev/null 2>&1
    sudo ufw --force enable
    sudo ufw allow 22/tcp
    sudo ufw allow ssh
    sudo ufw allow 40400/tcp
    sudo ufw allow 40400/udp
    sudo ufw allow 8080
    sudo ufw reload

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
    echo "--- Downloading snapshot (optional)..."
    wget -O $HOME/aztec-testnet.tar.lz4 https://files5.blacknodes.net/aztec/aztec-testnet.tar.lz4 || echo "⚠️ Snapshot not found. Skipping..."
    if [ -f "$HOME/aztec-testnet.tar.lz4" ]; then
      lz4 -d $HOME/aztec-testnet.tar.lz4 | tar x -C $HOME/.aztec/testnet
      rm $HOME/aztec-testnet.tar.lz4
      echo "✅ Snapshot installed!"
    fi

    # Step 10: Start node
    sudo docker compose -f ~/aztec/docker-compose.yml up -d
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
  for p in "40400/tcp" "40400/udp" "8080/tcp"; do
    proto=${p##*/}; port=${p%%/*}
    if nc -${proto:0:1} -z -w2 127.0.0.1 "$port" >/dev/null 2>&1; then
      echo "✅ Port $p is OPEN"
    else
      echo "❌ Port $p is CLOSED"
    fi
  done

  echo "--- Checking Peer ID..."
  PEER_ID=$(sudo docker logs aztec-sequencer 2>&1 | grep -o '"peerId":"[^"]*"' | head -n 1 | awk -F':' '{print $2}' | tr -d '"')
  [ -n "$PEER_ID" ] && echo "✅ Peer ID: $PEER_ID" || echo "⚠️ Peer ID not found."
}

check_node_performance() {
  echo "📊 Node Performance:"
  echo "--- CPU & Memory ---"
  top -b -n1 | head -n 5
  echo ""
  echo "--- Docker Stats ---"
  sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# ───────────────────────────────────────────────
# Menu
# ───────────────────────────────────────────────
while true; do
  show_header
  echo -e "${CYAN}1) Full Install (with Snapshot - optional)${NC}"
  echo -e "${CYAN}2) Run Node${NC}"
  echo -e "${CYAN}3) View Logs${NC}"
  echo -e "${CYAN}4) View & Reconfigure .env${NC}"
  echo -e "${CYAN}5) Check RPC Health${NC}"
  echo -e "${CYAN}6) Delete Node${NC}"
  echo -e "${CYAN}7) Check Ports & Peer ID${NC}"
  echo -e "${CYAN}8) Update Node${NC}"
  echo -e "${CYAN}9) Check Node Version${NC}"
  echo -e "${CYAN}10) Check Node Performance${NC}"
  echo -e "${CYAN}11) Exit${NC}"
  echo ""
  read -p "Choose option (1-11): " choice

  case $choice in
    1) install_aztec_node ;;
    2) cd ~/aztec && sudo docker compose up -d && sudo docker compose logs -f ;;
    3) cd ~/aztec && sudo docker compose logs -f ;;
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
         cd ~/aztec && docker compose down && sudo docker compose up -d
       fi
       ;;
    5) check_rpc_health ;;
    6) 
       echo -e "${RED}⚠️ This will delete your Aztec Node only:${NC}"
       echo "   - ~/aztec"
       echo "   - ~/.aztec/testnet"
       echo "   - Docker container: aztec-sequencer"
       read -p "➡ Are you sure? (Y/n): " confirm1
       if [[ "$confirm1" =~ ^[Yy]$ || -z "$confirm1" ]]; then
         read -p "➡ Are you REALLY sure? This cannot be undone. (Y/n): " confirm2
         if [[ "$confirm2" =~ ^[Yy]$ || -z "$confirm2" ]]; then
           sudo docker stop aztec-sequencer 2>/dev/null
           sudo docker rm aztec-sequencer 2>/dev/null
           sudo docker rmi aztecprotocol/aztec:2.0.2 2>/dev/null
           rm -rf ~/aztec ~/.aztec/testnet
           echo "✅ Node deleted."
         else
           echo "❌ Second confirmation failed. Cancelled."
         fi
       else
         echo "❌ Delete cancelled."
       fi
       ;;
    7) check_ports_and_peerid ;;
    8) sudo docker pull aztecprotocol/aztec:2.0.2 && (cd ~/aztec && sudo docker compose up -d) ;;
    9) sudo docker exec aztec-sequencer node /usr/src/yarn-project/aztec/dest/bin/index.js --version ;;
    10) check_node_performance ;;
    11) echo "Exiting..."; break ;;
    *) echo "Invalid option" ;;
  esac

  read -p "Press Enter to continue..."
done
