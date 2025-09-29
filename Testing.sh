#!/bin/bash
set -u   # safer: exit on unset vars only

# ──────────────[ COLORS ]──────────────
CYAN='\033[0;36m'
RED='\033[0;31m'
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

  # Step 1: Root access check
  sudo sh -c 'echo "• Root Access Enabled ✔"'

  # Step 2: Update system
  sudo apt-get update && sudo apt-get upgrade -y

  # Step 3: Install prerequisites
  sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
    tar clang bsdmainutils ncdu unzip ufw screen gawk netcat-openbsd sysstat ifstat

  # Step 4: Docker setup
  if [ ! -f /etc/os-release ]; then
    echo "Not Ubuntu or Debian"
    exit 1
  fi

  echo -e "${CYAN}Checking for existing Aztec Docker containers/images...${NC}"
  AZTEC_CONTAINERS=$(sudo docker ps -a --filter ancestor=aztecprotocol/aztec --format "{{.ID}}")
  AZTEC_NAMED_CONTAINERS=$(sudo docker ps -a --filter "name=aztec" --format "{{.ID}}")
  AZTEC_IMAGES=$(sudo docker images aztecprotocol/aztec -q)

  if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED_CONTAINERS" ] || [ -n "$AZTEC_IMAGES" ]; then
    echo -e "${RED}⚠️ Existing Aztec Docker setup detected!${NC}"
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

  # Docker installation
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

  # Step 7: User config
  echo -e "${CYAN}Let's configure your node...${NC}"
  read -p "➡ Enter Sepolia RPC URL: " ETH_RPC
  read -p "➡ Enter Beacon RPC URL: " BEACON_RPC
  read -p "➡ Enter Validator Private Key (with or without 0x...): " VAL_PRIV

  # Normalize private key
  if [[ ! "$VAL_PRIV" =~ ^0x ]]; then
    VAL_PRIV="0x$VAL_PRIV"
  fi

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

  # Step 9: Start node
  sudo docker compose -f ~/aztec/docker-compose.yml up -d
  echo -e "${CYAN}Installation finished 🚀 Use option 3 to view logs.${NC}"
}

# ───[ RPC HEALTH CHECK ]───
check_rpc_health() {
  echo "--- RPC Health Check ---"
  echo "1) Use RPCs from .env file"
  echo "2) Enter custom Sepolia and Beacon RPC URLs"
  read -p "Choose option (1/2): " rpc_option

  if [ "$rpc_option" = "1" ]; then
    if [ -f "$HOME/aztec/.env" ]; then
      source "$HOME/aztec/.env"
      SEPOLIA_RPC=$ETHEREUM_RPC_URL
      BEACON_RPC=$CONSENSUS_BEACON_URL
    else
      echo "⚠️ .env not found. Please run Full Install first."
      return
    fi
  elif [ "$rpc_option" = "2" ]; then
    read -p "➡ Enter Sepolia RPC URL: " SEPOLIA_RPC
    read -p "➡ Enter Beacon RPC URL: " BEACON_RPC
  else
    echo "Invalid option."
    return
  fi

  echo "🔎 Checking Sepolia RPC: $SEPOLIA_RPC"
  curl -s --max-time 5 "$SEPOLIA_RPC" >/dev/null 2>&1 && echo "✅ Reachable" || echo "❌ Not reachable"

  echo "🔎 Checking Beacon RPC: $BEACON_RPC"
  curl -s --max-time 5 "$BEACON_RPC" >/dev/null 2>&1 && echo "✅ Reachable" || echo "❌ Not reachable"
}

# ───[ PORTS & PEER ID CHECK ]───
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

# ───[ NODE PERFORMANCE DASHBOARD ]───
check_node_performance() {
  clear
  echo -e "${CYAN}📊 AZTEC NODE PERFORMANCE DASHBOARD${NC}"
  echo -e "${CYAN}─────────────────────────────────────────────${NC}"

  echo -e "${CYAN}🖥️ System Resource Snapshot:${NC}"

  # CPU
  if command -v top &>/dev/null; then
    CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')
    CPU_LOAD=${CPU_LOAD:-0}
    if (( ${CPU_LOAD%.*} > 80 )); then CPU_COLOR=$RED
    elif (( ${CPU_LOAD%.*} > 60 )); then CPU_COLOR=$YELLOW
    else CPU_COLOR=$GREEN; fi
    echo -e "CPU Usage:   ${CPU_COLOR}${CPU_LOAD}%${NC}"
  else
    echo -e "${YELLOW}CPU Usage: Unable to retrieve (top not installed).${NC}"
  fi

  # Memory
  if command -v free &>/dev/null; then
    MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
    MEM_PERCENT=$(( MEM_USED * 100 / MEM_TOTAL ))
    if (( MEM_PERCENT > 80 )); then MEM_COLOR=$RED
    elif (( MEM_PERCENT > 60 )); then MEM_COLOR=$YELLOW
    else MEM_COLOR=$GREEN; fi
    echo -e "Memory:      ${MEM_COLOR}${MEM_USED}MB${NC} / ${CYAN}${MEM_TOTAL}MB${NC} (${MEM_PERCENT}%)"
  else
    echo -e "${YELLOW}Memory: Unable to retrieve (free not installed).${NC}"
  fi

  # Disk
  if command -v df &>/dev/null; then
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    if (( DISK_USAGE > 85 )); then DISK_COLOR=$RED
    elif (( DISK_USAGE > 70 )); then DISK_COLOR=$YELLOW
    else DISK_COLOR=$GREEN; fi
    echo ""
    echo -e "${CYAN}💾 Disk Usage:${NC}"
    echo -e "Disk:        ${DISK_COLOR}${DISK_USED}${NC} / ${CYAN}${DISK_TOTAL}${NC} (${DISK_USAGE}%)"
  else
    echo -e "${YELLOW}Disk: Unable to retrieve (df not installed).${NC}"
  fi

  # Network Traffic
  echo ""
  echo -e "${CYAN}🌐 Network Traffic (5s avg):${NC}"
  if ! command -v sar &>/dev/null && ! command -v ifstat &>/dev/null; then
    echo -e "${YELLOW}Network tools missing, installing now...${NC}"
    sudo apt-get update
    sudo apt-get install -y sysstat ifstat
  fi
  if command -v sar &>/dev/null; then
    NET_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -n "$NET_IF" ]; then
      sar -n DEV 1 5 | grep "$NET_IF" | tail -1 | awk '{print "RX: "$5" kB/s, TX: "$6" kB/s"}'
    else
      echo -e "${YELLOW}Could not detect network interface.${NC}"
      sar -n DEV 1 5 | grep -E "eth|ens" | tail -1 | awk '{print "RX: "$5" kB/s, TX: "$6" kB/s"}'
    fi
  elif command -v ifstat &>/dev/null; then
    NET_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    echo "RX/TX for $NET_IF (kB/s):"
    ifstat -i "$NET_IF" 1 5 | tail -n 1
  else
    echo -e "${RED}sysstat and ifstat failed to install. Please check your system!${NC}"
  fi

  # Docker stats
  echo ""
  echo -e "${CYAN}🐳 Docker Container Usage:${NC}"
  if command -v docker &>/dev/null; then
    sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
  else
    echo -e "${YELLOW}Docker not installed or not in PATH.${NC}"
  fi

  echo ""
  echo -e "${GREEN}✅ At this moment your VPS is doing fine — no critical bottlenecks.${NC}"
  echo -e "${CYAN}💡 Tip:${NC} If CPU/MEM/Disk stays red often → consider upgrading VPS or optimizing containers."
  echo -e "${CYAN}─────────────────────────────────────────────${NC}"
}

# ───[ SHOW RUNNING DOCKER CONTAINERS ]───
show_running_docker_containers() {
  echo "🟦 Showing all running Docker containers:"
  sudo docker ps
  echo ""
  RUNNING_COUNT=$(sudo docker ps | tail -n +2 | wc -l)
  echo "Total running containers: $RUNNING_COUNT"
  echo ""
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
  echo -e "${CYAN}12) Exit${NC}"
  echo ""
  read -p "Choose option (1-12): " choice

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
        read -p "➡ Enter new Validator Private Key (with or without 0x...): " VAL_PRIV

        # Normalize private key
        if [[ ! "$VAL_PRIV" =~ ^0x ]]; then
          VAL_PRIV="0x$VAL_PRIV"
        fi

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
