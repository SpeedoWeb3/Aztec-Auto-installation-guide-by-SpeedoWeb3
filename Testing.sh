#!/bin/bash
set -u   # safer: exit on unset vars only

# ──────────────[ COLORS ]──────────────
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# ──────────────[ HEADER ]──────────────
show_header() {
  clear
  echo -e "${CYAN}==============================================================="
  echo "                     🚀 AZTEC NODE GUIDE 🚀"
  echo "               Script made by SpeedoWeb3 with ♥️"
  echo "              X:@SpeedoWeb3 || Discord:@SpeedoWeb3"
  echo -e "===============================================================${NC}"
}

# ───[ FULL INSTALLATION ]───
install_aztec_node() {
  echo -e "${CYAN}Starting Full Aztec Node Installation...${NC}"

  sudo sh -c 'echo "• Root Access Enabled ✔"'

  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
    tar clang bsdmainutils ncdu unzip ufw screen gawk netcat-openbsd sysstat ifstat

  if [ ! -f /etc/os-release ]; then
    echo "Not Ubuntu or Debian"
    exit 1
  fi

  echo -e "${CYAN}Checking for existing Aztec Docker containers/images...${NC}"
  AZTEC_CONTAINERS=$(sudo docker ps -a --filter ancestor=aztecprotocol/aztec --format "{{.ID}}")
  AZTEC_NAMED_CONTAINERS=$(sudo docker ps -a --filter "name=aztec" --format "{{.ID}}")
  AZTEC_IMAGES=$(sudo docker images aztecprotocol/aztec -q)

  if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED_CONTAINERS" ] || [ -n "$AZTEC_IMAGES" ]; then
    echo "⚠️ Existing Aztec Docker setup detected!"
    echo "Containers: ${AZTEC_CONTAINERS:-None} ${AZTEC_NAMED_CONTAINERS:-None}"
    echo "Images: ${AZTEC_IMAGES:-None}"
    read -p "➡ Do you want to delete and reinstall Aztec only? (Y/n): " del_choice
    if [[ ! "$del_choice" =~ ^[Yy]$ && -n "$del_choice" ]]; then
      echo "❌ Installation cancelled."
      return
    fi
    if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED_CONTAINERS" ]; then
      echo "Stopping and removing Aztec containers..."
      sudo docker stop $AZTEC_CONTAINERS $AZTEC_NAMED_CONTAINERS 2>/dev/null
      sudo docker rm $AZTEC_CONTAINERS $AZTEC_NAMED_CONTAINERS 2>/dev/null
    fi
    if [ -n "$AZTEC_IMAGES" ]; then
      echo "Removing Aztec images..."
      sudo docker rmi -f $AZTEC_IMAGES 2>/dev/null
    fi
    rm -f ~/aztec/docker-compose.yml ~/aztec/.env
    echo "✅ Old Aztec Docker setup removed."
  fi

  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl restart docker
  echo -e "${CYAN}• Docker Installed ✔${NC}"

  sudo usermod -aG docker $USER
  echo "✅ User added to docker group. Please log out and log back in."

  sudo apt install -y ufw >/dev/null 2>&1
  sudo ufw --force enable
  sudo ufw allow 22/tcp
  sudo ufw allow ssh
  sudo ufw allow 40400/tcp
  sudo ufw allow 40400/udp
  sudo ufw allow 8080
  sudo ufw reload

  rm -rf ~/aztec && mkdir ~/aztec && cd ~/aztec

  echo -e "${CYAN}Let's configure your node...${NC}"

# Sepolia RPC URL
read -p "➡ Enter Sepolia RPC URL: " ETH_RPC
if [[ -z "$ETH_RPC" ]]; then
  echo -e "${YELLOW}⚠️ Sepolia RPC URL is required.${NC}"
  exit 1
fi

# Beacon RPC URL
read -p "➡ Enter Beacon RPC URL: " BEACON_RPC
if [[ -z "$BEACON_RPC" ]]; then
  echo -e "${YELLOW}⚠️ Beacon RPC URL is required.${NC}"
  exit 1
fi

# Validator Private Key
read -p "➡ Enter Validator Private Key (with or without 0x...): " VAL_PRIV
if [[ -z "$VAL_PRIV" ]]; then
  echo -e "${YELLOW}⚠️ Validator Private Key is required.${NC}"
  exit 1
fi
if [[ "$VAL_PRIV" != 0x* ]]; then
  VAL_PRIV="0x$VAL_PRIV"
fi
echo -e "${GREEN}Validator Private Key set to: $VAL_PRIV${NC}"

# Wallet Address
read -p "➡ Enter Wallet Address (0x...): " WALLET_ADDR
if [[ -z "$WALLET_ADDR" || "$WALLET_ADDR" != 0x* ]]; then
  echo -e "${YELLOW}⚠️ Wallet Address must start with 0x and cannot be empty.${NC}"
  exit 1
fi

# VPS IP detection
VPS_IP=$(curl -s ipv4.icanhazip.com)
if [[ -z "$VPS_IP" ]]; then
  echo -e "${YELLOW}⚠️ Could not detect VPS IP.${NC}"
else
  echo "➡ Auto-detected VPS IP: $VPS_IP"
fi

  cat > .env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF

  echo -e "${CYAN}.env file created successfully ✅${NC}"

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

  sudo docker compose -f ~/aztec/docker-compose.yml up -d
  echo -e "${CYAN}Installation finished 🚀 Use option 3 to view logs.${NC}"
}

# ───[ PORTS & PEER ID CHECK ]───
check_ports_and_peerid() {
  echo "Checking important ports..."
  for port in 40400 8080; do
    if ss -lntu 2>/dev/null | grep -q ":$port "; then
      echo "✅ Port $port is OPEN (TCP/UDP)"
    else
      echo "❌ Port $port seems CLOSED"
    fi
  done

  echo "--- Checking Peer ID..."
  PEER_ID=$(sudo docker logs aztec-sequencer 2>&1 | grep -o '"peerId":"[^"]*"' | head -n 1 | awk -F':' '{print $2}' | tr -d '"')
  [ -n "$PEER_ID" ] && echo "✅ Peer ID: $PEER_ID" || echo "⚠️ Peer ID not found (node may still be syncing)."
}

# ───[ DOZZLE LOG VIEWER ]───
launch_dozzle() {
  if sudo docker ps --format '{{.Names}}' | grep -q '^dozzle$'; then
    VPS_IP=$(curl -s ipv4.icanhazip.com)
    echo "✅ Dozzle is already running."
    echo "🌐 You can view logs for Aztec and other Docker containers using your browser."
    echo "👉 Open: http://$VPS_IP:9999"
    echo "🔎 In Dozzle, search for 'aztec-sequencer' to view Aztec node logs."
  else
    echo "🚀 Launching Dozzle (Docker Log Viewer)..."
    sudo docker run -d --name dozzle --restart unless-stopped -p 9999:8080 \
      -v /var/run/docker.sock:/var/run/docker.sock amir20/dozzle:latest >/dev/null 2>&1
    VPS_IP=$(curl -s ipv4.icanhazip.com)
    echo "✅ Dozzle is running."
    echo "🌐 You can view logs for Aztec and other Docker containers using your browser."
    echo "👉 Open: http://$VPS_IP:9999"
    echo "🔎 In Dozzle, search for 'aztec-sequencer' to view Aztec node logs."
  fi
}

# ───[ DELETE NODE ONLY ]───
delete_node() {
  echo "This will delete your Aztec Node only:"
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
}

# ──────────────[ MAIN MENU ]──────────────
while true; do
  show_header
  echo -e "${CYAN}1) Full Install${NC}"
  echo -e "${CYAN}2) Run Node${NC}"
  echo -e "${CYAN}3) View Logs${NC}"
  echo -e "${CYAN}4) View & Reconfigure .env${NC}"
  echo -e "${CYAN}5) Check RPC Health${NC}"
  echo -e "${CYAN}6) Delete Node${NC}"
  echo -e "${CYAN}7) Check Ports & Peer ID${NC}"
  echo -e "${CYAN}8) Update Node${NC}"
  echo -e "${CYAN}9) Check Node Version${NC}"
  echo -e "${CYAN}10) Check Node Performance${NC}"
  echo -e "${CYAN}11) Show Running Docker Containers${NC}"
  echo -e "${CYAN}12) Launch Dozzle (Log Viewer)${NC}"
  echo -e "${CYAN}13) Exit${NC}"
  echo ""
  read -p "Choose option (1-13): " choice

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
        if [[ "$VAL_PRIV" != 0x* ]]; then VAL_PRIV="0x$VAL_PRIV"; fi
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
        cd ~/aztec && sudo docker compose up -d
      fi
      ;;
    5) check_rpc_health ;;
    6) delete_node ;;
    7) check_ports_and_peerid ;;
    8) sudo docker pull aztecprotocol/aztec:2.0.2 && (cd ~/aztec && sudo docker compose up -d) ;;
    9) sudo docker exec aztec-sequencer node /usr/src/yarn-project/aztec/dest/bin/index.js --version ;;
    10) check_node_performance ;;
    11) show_running_docker_containers ;;
    12) launch_dozzle ;;
    13) echo "Exiting..."; break ;;
    *) echo "Invalid option" ;;
  esac

  read -p "Press Enter to continue..."
done
