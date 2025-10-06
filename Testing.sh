#!/bin/bash
set -u   # safer: exit on unset vars only

# ──────────────[ COLORS ]──────────────
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
ORANGE='\033[1;33m'
AMBER='\033[0;33m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

  # Step 3: Install prerequisites (includes sysstat and ifstat for network stats)
  sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
    tar clang bsdmainutils ncdu unzip ufw screen gawk netcat-openbsd sysstat ifstat net-tools bc

  # Step 4: Docker setup (safe cleanup only for Aztec)
  if [ ! -f /etc/os-release ]; then
    echo "Not Ubuntu or Debian"
    exit 1
  fi

  echo -e "${CYAN}Checking for existing Aztec Docker containers/images...${NC}"
  AZTEC_CONTAINERS=$(sudo docker ps -a --filter ancestor=aztecprotocol/aztec --format "{{.ID}}" 2>/dev/null)
  AZTEC_NAMED_CONTAINERS=$(sudo docker ps -a --filter "name=aztec" --format "{{.ID}}" 2>/dev/null)
  AZTEC_IMAGES=$(sudo docker images aztecprotocol/aztec -q 2>/dev/null)

  if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED_CONTAINERS" ] || [ -n "$AZTEC_IMAGES" ]; then
    echo -e "${RED}⚠️ Existing Aztec Docker setup detected!${NC}"
    echo "Containers: ${AZTEC_CONTAINERS:-None} ${AZTEC_NAMED_CONTAINERS:-None}"
    echo "Images: ${AZTEC_IMAGES:-None}"
    read -p "➡ Do you want to delete and reinstall Aztec only? (Y/n): " del_choice
    if [[ ! "$del_choice" =~ ^[Yy]$ && -n "$del_choice" ]]; then
      echo "❌ Installation cancelled."
      return
    fi
    # Stop and remove all containers found
    if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED_CONTAINERS" ]; then
      echo "Stopping and removing Aztec containers..."
      sudo docker stop $AZTEC_CONTAINERS $AZTEC_NAMED_CONTAINERS 2>/dev/null
      sudo docker rm $AZTEC_CONTAINERS $AZTEC_NAMED_CONTAINERS 2>/dev/null
    fi
    # Remove Aztec images (force)
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

  # Step 7: User config with auto 0x prefix
  echo -e "${CYAN}Let's configure your node...${NC}"
  read -p "➡ Enter Sepolia RPC URL: " ETH_RPC
  read -p "➡ Enter Beacon RPC URL: " BEACON_RPC
  read -p "➡ Enter Validator Private Key: " VAL_PRIV
  read -p "➡ Enter Wallet Address: " WALLET_ADDR
  
  # Auto add 0x prefix if missing
  if [[ ! "$VAL_PRIV" =~ ^0x ]]; then
    VAL_PRIV="0x$VAL_PRIV"
    echo "✅ Auto-added 0x prefix to private key"
  else
    echo "✅ Private key already has 0x prefix"
  fi
  
  if [[ ! "$WALLET_ADDR" =~ ^0x ]]; then
    WALLET_ADDR="0x$WALLET_ADDR"
    echo "✅ Auto-added 0x prefix to wallet address"
  else
    echo "✅ Wallet address already has 0x prefix"
  fi
  
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

  # Step 8: Create docker-compose.yml with version 2.0.2
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
  echo -e "${CYAN}Installation finished with version 2.0.2 🚀 Use option 3 to view logs.${NC}"
  read -p "Press Enter to continue..."
}

# ───[ ENHANCED RPC HEALTH CHECK - NINJA STYLE ]───
check_rpc_health() {
  while true; do
    clear
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         🔍 ETHEREUM NODE HEALTH SCANNER${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${AMBER}1) Check RPC health from .env${NC}"
    echo -e "${AMBER}2) Check Custom RPC health${NC}"
    echo -e "${AMBER}3) Back to Main Menu${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
    read -p "$(echo -e "${AMBER}Choose option (1-3): ${NC}")" rpc_option
    
    case $rpc_option in
      1)
        if [ -f "$HOME/aztec/.env" ]; then
          source "$HOME/aztec/.env"
          SEPOLIA_RPC=$ETHEREUM_RPC_URL
          BEACON_RPC=$CONSENSUS_BEACON_URL
          
          if [ -z "$SEPOLIA_RPC" ] || [ -z "$BEACON_RPC" ]; then
            echo -e "${RED}⚠️ RPC URLs not found in .env${NC}"
            read -p "Press Enter to continue..."
            continue
          fi
          
          perform_rpc_check "$SEPOLIA_RPC" "$BEACON_RPC" ".env Configuration"
        else
          echo -e "${RED}⚠️ .env file not found at $HOME/aztec/.env${NC}"
          read -p "Press Enter to continue..."
        fi
        ;;
        
      2)
        echo ""
        read -p "$(echo -e ${AMBER}➡ Enter Sepolia RPC URL: ${NC})" SEPOLIA_RPC
        read -p "$(echo -e ${AMBER}➡ Enter Beacon RPC URL: ${NC})" BEACON_RPC
        
        if [ -z "$SEPOLIA_RPC" ] || [ -z "$BEACON_RPC" ]; then
          echo -e "${RED}⚠️ Both RPC URLs are required${NC}"
          read -p "Press Enter to continue..."
          continue
        fi
        
        perform_rpc_check "$SEPOLIA_RPC" "$BEACON_RPC" "Custom Configuration"
        ;;
        
      3)
        break
        ;;
        
      *)
        echo -e "${RED}Invalid option${NC}"
        sleep 1
        ;;
    esac
  done
}

# Helper function for RPC health check
perform_rpc_check() {
  local SEPOLIA_RPC=$1
  local BEACON_RPC=$2
  local CONFIG_TYPE=$3
  
  clear
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e "${BLUE}           ETHEREUM NODE HEALTH CHECK${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e "${CYAN}Configuration: ${WHITE}$CONFIG_TYPE${NC}"
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  
  # Sepolia RPC Check
  echo ""
  echo -e "${CYAN}● Sepolia RPC Analysis${NC}"
  BLOCK_RESPONSE=$(curl -s --max-time 5 -X POST "$SEPOLIA_RPC" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null)
  
  SEPOLIA_SCORE=0
  if echo "$BLOCK_RESPONSE" | grep -q "result"; then
    BLOCK_HEX=$(echo "$BLOCK_RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    BLOCK_NUM=$((16#${BLOCK_HEX#0x}))
    echo -e "  Status       : ${GREEN}Online ✓${NC}"
    echo -e "  Block Height : ${WHITE}#$BLOCK_NUM${NC}"
    ((SEPOLIA_SCORE+=50))
    
    # Check network ID
    NET_RESPONSE=$(curl -s --max-time 5 -X POST "$SEPOLIA_RPC" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' 2>/dev/null)
    NET_ID=$(echo "$NET_RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    if [ "$NET_ID" = "11155111" ]; then
      echo -e "  Network      : ${GREEN}Sepolia${NC}"
      ((SEPOLIA_SCORE+=50))
    fi
    
    # Response time check
    START_TIME=$(date +%s%N)
    curl -s --max-time 1 -X POST "$SEPOLIA_RPC" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' >/dev/null 2>&1
    END_TIME=$(date +%s%N)
    RESPONSE_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    
    if [ "$RESPONSE_MS" -lt 100 ]; then
      echo -e "  Speed        : ${GREEN}Fast${NC} (${RESPONSE_MS}ms)"
      SEPOLIA_RATING="${GREEN}Excellent${NC}"
    elif [ "$RESPONSE_MS" -lt 500 ]; then
      echo -e "  Speed        : ${YELLOW}Moderate${NC} (${RESPONSE_MS}ms)"
      SEPOLIA_RATING="${YELLOW}Good${NC}"
    else
      echo -e "  Speed        : ${RED}Slow${NC} (${RESPONSE_MS}ms)"
      SEPOLIA_RATING="${RED}Poor${NC}"
    fi
  else
    echo -e "  Status       : ${RED}Offline ✗${NC}"
    echo -e "  Block Height : ${RED}N/A${NC}"
    echo -e "  Network      : ${RED}N/A${NC}"
    echo -e "  Speed        : ${RED}N/A${NC}"
    SEPOLIA_RATING="${RED}Failed${NC}"
  fi
  echo -e "  Rating       : $SEPOLIA_RATING"
  
  # Beacon Node Check
  echo ""
  echo -e "${CYAN}● Beacon Node Analysis${NC}"
  VERSION_RESPONSE=$(curl -s --max-time 5 "$BEACON_RPC/eth/v1/node/version" 2>/dev/null)
  
  BEACON_SCORE=0
  if [ -n "$VERSION_RESPONSE" ] && echo "$VERSION_RESPONSE" | grep -q "version"; then
    VERSION=$(echo "$VERSION_RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 | cut -d'/' -f1)
    echo -e "  Status       : ${GREEN}Online ✓${NC}"
    echo -e "  Client       : ${WHITE}$VERSION${NC}"
    ((BEACON_SCORE+=30))
    
    # Sync status
    SYNC_RESPONSE=$(curl -s --max-time 5 "$BEACON_RPC/eth/v1/node/syncing" 2>/dev/null)
    if echo "$SYNC_RESPONSE" | grep -q '"is_syncing":false'; then
      echo -e "  Sync Status  : ${GREEN}Synced${NC}"
      ((BEACON_SCORE+=40))
    elif echo "$SYNC_RESPONSE" | grep -q '"is_syncing":true'; then
      echo -e "  Sync Status  : ${YELLOW}Syncing${NC}"
      ((BEACON_SCORE+=20))
    else
      echo -e "  Sync Status  : ${YELLOW}Unknown${NC}"
    fi
    
    # Peer count
    PEER_RESPONSE=$(curl -s --max-time 5 "$BEACON_RPC/eth/v1/node/peer_count" 2>/dev/null)
    PEER_COUNT=$(echo "$PEER_RESPONSE" | grep -o '"connected":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$PEER_COUNT" ] && [ "$PEER_COUNT" -gt 0 ]; then
      if [ "$PEER_COUNT" -ge 50 ]; then
        echo -e "  Peers        : ${GREEN}$PEER_COUNT${NC}"
        ((BEACON_SCORE+=30))
      elif [ "$PEER_COUNT" -ge 20 ]; then
        echo -e "  Peers        : ${YELLOW}$PEER_COUNT${NC}"
        ((BEACON_SCORE+=20))
      else
        echo -e "  Peers        : ${RED}$PEER_COUNT${NC}"
        ((BEACON_SCORE+=10))
      fi
    else
      echo -e "  Peers        : ${YELLOW}Unknown${NC}"
    fi
    
    # Determine beacon rating
    if [ "$BEACON_SCORE" -ge 80 ]; then
      BEACON_RATING="${GREEN}Excellent${NC}"
    elif [ "$BEACON_SCORE" -ge 60 ]; then
      BEACON_RATING="${YELLOW}Good${NC}"
    elif [ "$BEACON_SCORE" -ge 40 ]; then
      BEACON_RATING="${AMBER}Fair${NC}"
    else
      BEACON_RATING="${RED}Poor${NC}"
    fi
  else
    echo -e "  Status       : ${RED}Offline ✗${NC}"
    echo -e "  Client       : ${RED}N/A${NC}"
    echo -e "  Sync Status  : ${RED}N/A${NC}"
    echo -e "  Peers        : ${RED}N/A${NC}"
    BEACON_RATING="${RED}Failed${NC}"
  fi
  echo -e "  Rating       : $BEACON_RATING"
  
  # Blob Check (simplified)
  echo ""
  echo -e "${CYAN}● Blob Sidecars Analysis${NC}"
  
  HEAD_RESPONSE=$(curl -s --max-time 5 "$BEACON_RPC/eth/v2/beacon/blocks/head" 2>/dev/null)
  CURRENT_SLOT=$(echo "$HEAD_RESPONSE" | grep -o '"slot":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [ -n "$CURRENT_SLOT" ]; then
    BLOB_SUCCESS=0
    TOTAL_BLOBS=0
    
    # Check last 5 slots silently
    for i in {0..4}; do
      SLOT=$((CURRENT_SLOT - i))
      BLOB_RESPONSE=$(curl -s --max-time 2 "$BEACON_RPC/eth/v1/beacon/blob_sidecars/$SLOT" 2>/dev/null)
      
      if echo "$BLOB_RESPONSE" | grep -q "data"; then
        BLOB_COUNT=$(echo "$BLOB_RESPONSE" | grep -o '"blob"' | wc -l)
        if [ "$BLOB_COUNT" -gt 0 ]; then
          ((BLOB_SUCCESS++))
          ((TOTAL_BLOBS+=BLOB_COUNT))
        fi
      fi
    done
    
    BLOB_PERCENTAGE=$((BLOB_SUCCESS * 100 / 5))
    
    if [ "$BLOB_PERCENTAGE" -ge 80 ]; then
      echo -e "  Availability : ${GREEN}Excellent${NC} (${BLOB_PERCENTAGE}%)"
      BLOB_RATING="${GREEN}Excellent${NC}"
    elif [ "$BLOB_PERCENTAGE" -ge 60 ]; then
      echo -e "  Availability : ${YELLOW}Good${NC} (${BLOB_PERCENTAGE}%)"
      BLOB_RATING="${YELLOW}Good${NC}"
    elif [ "$BLOB_PERCENTAGE" -ge 40 ]; then
      echo -e "  Availability : ${AMBER}Fair${NC} (${BLOB_PERCENTAGE}%)"
      BLOB_RATING="${AMBER}Fair${NC}"
    else
      echo -e "  Availability : ${RED}Poor${NC} (${BLOB_PERCENTAGE}%)"
      BLOB_RATING="${RED}Poor${NC}"
    fi
    
    echo -e "  Total Blobs  : ${WHITE}$TOTAL_BLOBS${NC} in last 5 slots"
    echo -e "  Rating       : $BLOB_RATING"
  else
    echo -e "  Availability : ${RED}Unable to check${NC}"
    echo -e "  Total Blobs  : ${RED}N/A${NC}"
    echo -e "  Rating       : ${RED}Failed${NC}"
  fi
  
  # Overall Summary
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e "${BLUE}              📊 OVERALL ASSESSMENT${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  
  # Calculate overall health
  if [ "$SEPOLIA_SCORE" -eq 100 ] && [ "$BEACON_SCORE" -ge 80 ] && [ "$BLOB_PERCENTAGE" -ge 60 ]; then
    echo -e ""
    echo -e "  ${GREEN}✓ EXCELLENT - Ready for Aztec${NC}"
    echo -e ""
    echo -e "  All systems operational and performing well"
  elif [ "$SEPOLIA_SCORE" -ge 50 ] && [ "$BEACON_SCORE" -ge 40 ]; then
    echo -e ""
    echo -e "  ${YELLOW}⚠ GOOD - Functional but could be improved${NC}"
    echo -e ""
    echo -e "  Your node is working but check the ratings above"
  else
    echo -e ""
    echo -e "  ${RED}✗ POOR - Not recommended for production${NC}"
    echo -e ""
    echo -e "  Please fix the issues shown above"
  fi
  
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo ""
  read -p "Press Enter to continue..."
}

# ───[ PORTS & PEER ID CHECK ]───
check_ports_and_peerid() {
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  echo -e "${AMBER}Checking important ports...${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  for p in "40400/tcp" "40400/udp" "8080/tcp"; do
    proto=${p##*/}; port=${p%%/*}
    if nc -${proto:0:1} -z -w2 127.0.0.1 "$port" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Port $p is OPEN${NC}"
    else
      echo -e "${RED}❌ Port $p is CLOSED${NC}"
    fi
  done

  echo ""
  echo -e "${AMBER}--- Checking Peer ID...${NC}"
  PEER_ID=$(sudo docker logs aztec-sequencer 2>&1 | grep -o '"peerId":"[^"]*"' | head -n 1 | awk -F':' '{print $2}' | tr -d '"')
  if [ -n "$PEER_ID" ]; then
    echo -e "${GREEN}✅ Peer ID: $PEER_ID${NC}"
  else
    echo -e "${YELLOW}⚠️ Peer ID not found yet (node may still be starting).${NC}"
  fi
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
}

# ───[ NODE PERFORMANCE DASHBOARD ]───
check_node_performance() {
  clear
  echo -e "${AMBER}📊 AZTEC NODE PERFORMANCE DASHBOARD${NC}"
  echo -e "${AMBER}─────────────────────────────────────────────${NC}"

  echo -e "${AMBER}🖥️ System Resource Snapshot:${NC}"

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
    echo -e "Memory:      ${MEM_COLOR}${MEM_USED}MB${NC} / ${AMBER}${MEM_TOTAL}MB${NC} (${MEM_PERCENT}%)"
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
    echo -e "${AMBER}💾 Disk Usage:${NC}"
    echo -e "Disk:        ${DISK_COLOR}${DISK_USED}${NC} / ${AMBER}${DISK_TOTAL}${NC} (${DISK_USAGE}%)"
  else
    echo -e "${YELLOW}Disk: Unable to retrieve (df not installed).${NC}"
  fi

  # Network Traffic
  echo ""
  echo -e "${AMBER}🌐 Network Traffic (5s avg):${NC}"
  if command -v sar &>/dev/null; then
    NET_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -n "$NET_IF" ]; then
      sar -n DEV 1 5 | grep "$NET_IF" | tail -1 | awk '{print "RX: "$5" kB/s, TX: "$6" kB/s"}'
    else
      echo -e "${YELLOW}Could not detect network interface.${NC}"
    fi
  elif command -v ifstat &>/dev/null; then
    NET_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    echo "RX/TX for $NET_IF (kB/s):"
    ifstat -i "$NET_IF" 1 5 | tail -n 1
  else
    echo -e "${YELLOW}Network monitoring tools not available.${NC}"
  fi

  # Docker stats
  echo ""
  echo -e "${AMBER}🐳 Docker Container Usage:${NC}"
  if command -v docker &>/dev/null; then
    sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
  else
    echo -e "${YELLOW}Docker not installed or not in PATH.${NC}"
  fi

  echo ""
  echo -e "${GREEN}✅ Performance check complete.${NC}"
  echo -e "${AMBER}💡 Tip:${NC} If CPU/MEM/Disk stays red often → consider upgrading VPS or optimizing containers."
  echo -e "${AMBER}─────────────────────────────────────────────${NC}"
}

# ───[ SHOW ONLY RUNNING DOCKER CONTAINERS ]───
show_running_docker_containers() {
  echo ""
  echo -e "${AMBER}🐳  Running Docker Containers${NC}"
  echo -e "${AMBER}────────────────────────────────────────────${NC}"
  echo ""

  CONTAINERS=$(sudo docker ps -q)

  if [ -z "$CONTAINERS" ]; then
    echo -e "${AMBER}⚠️  No containers are currently running.${NC}"
  else
    for ID in $CONTAINERS; do
      NAME=$(sudo docker inspect -f '{{.Name}}' "$ID" | sed 's|/||')
      IMAGE=$(sudo docker inspect -f '{{.Config.Image}}' "$ID")
      STATUS=$(sudo docker inspect -f '{{.State.Status}}' "$ID")
      NETWORK_MODE=$(sudo docker inspect -f '{{.HostConfig.NetworkMode}}' "$ID")
      STARTED_AT=$(sudo docker inspect -f '{{.State.StartedAt}}' "$ID" | cut -d'.' -f1)
      
      # Calculate uptime
      if [ -n "$STARTED_AT" ]; then
        START_TS=$(date -d "$STARTED_AT" +%s 2>/dev/null)
        NOW_TS=$(date +%s)
        UPTIME_SEC=$((NOW_TS - START_TS))
        UPTIME_FMT=$(printf '%dd %02dh %02dm %02ds' $((UPTIME_SEC/86400)) $((UPTIME_SEC%86400/3600)) $((UPTIME_SEC%3600/60)) $((UPTIME_SEC%60)))
      else
        UPTIME_FMT="Unknown"
      fi

      # Ports
      PORTS=$(sudo docker port "$ID" 2>/dev/null | paste -sd ", " -)
      if [ "$NETWORK_MODE" = "host" ] && [ -z "$PORTS" ]; then
        if command -v ss &>/dev/null; then
          PORTS=$(sudo ss -tulnp 2>/dev/null | grep -E "40400|8080" | awk '{print $5}' | cut -d':' -f2 | sort -u | paste -sd ", " -)
        elif command -v netstat &>/dev/null; then
          PORTS=$(sudo netstat -tulnp 2>/dev/null | grep -E "40400|8080" | awk '{print $4}' | cut -d':' -f2 | sort -u | paste -sd ", " -)
        fi
      fi

      # ───[ SIMPLIFIED DOZZLE MANAGER ]───
launch_dozzle() {
  while true; do
    clear
    echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
    echo -e "${AMBER}     🪩 DOZZLE LOG VIEWER CONTROL CENTER${NC}"
    echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${AMBER}1) 🚀 Install Dozzle${NC}"
    echo -e "${AMBER}2) 👀 View Dozzle Status & Access${NC}"
    echo -e "${AMBER}3) 🗑️  Remove Dozzle${NC}"
    echo -e "${AMBER}4) ↩️  Back to Main Menu${NC}"
    echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
    read -p "Choose an option (1-4): " dozzle_choice

    case $dozzle_choice in
      1)
        echo ""
        # Check if already installed
        if sudo docker ps --format '{{.Names}}' | grep -q '^dozzle$'; then
          echo -e "${GREEN}✅ Dozzle is already installed and running!${NC}"
          echo ""
          VPS_IP=$(curl -s ipv4.icanhazip.com)
          
          DOZZLE_STATUS=$(sudo docker ps --filter "name=dozzle" --format "table {{.Status}}" | tail -n 1)
          DOZZLE_IMAGE=$(sudo docker inspect dozzle --format='{{.Config.Image}}' 2>/dev/null)
          
          echo -e "${CYAN}📦 Image: ${WHITE}$DOZZLE_IMAGE${NC}"
          echo -e "${CYAN}⏱️ Uptime: ${WHITE}$DOZZLE_STATUS${NC}"
          echo ""
          echo -e "${CYAN}🌐 Access URL: ${WHITE}http://$VPS_IP:9999${NC}"
          echo ""
          echo -e "${AMBER}📝 Quick Guide:${NC}"
          echo -e "  1️⃣  Open the URL in your browser"
          echo -e "  2️⃣  Search for '${WHITE}aztec-sequencer${NC}' in the container list"
          echo -e "  3️⃣  Click to view real-time logs"
          echo -e "  4️⃣  Use filters to search specific events"
          echo ""
          echo -e "${CYAN}💡 Pro Tips:${NC}"
          echo -e "  • Use ${WHITE}Ctrl+F${NC} to search within logs"
          echo -e "  • Click the ${WHITE}⚙️ gear icon${NC} for settings"
          echo -e "  • Enable ${WHITE}dark mode${NC} for better visibility"
          echo ""
        else
          echo -e "${CYAN}🚀 Installing Dozzle for the first time...${NC}"
          echo -e "${CYAN}This will give you a beautiful web interface to view logs!${NC}"
          
          # Pull and run Dozzle
          sudo docker pull amir20/dozzle:latest >/dev/null 2>&1
          sudo docker run -d --name dozzle --restart unless-stopped \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -p 9999:8080 amir20/dozzle:latest >/dev/null 2>&1
          
          # Firewall rules
          sudo ufw allow 9999 >/dev/null 2>&1
          sudo ufw reload >/dev/null 2>&1
          
          VPS_IP=$(curl -s ipv4.icanhazip.com)
          echo ""
          echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
          echo -e "${GREEN}║     ✨ DOZZLE SUCCESSFULLY DEPLOYED! ✨    ║${NC}"
          echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
          echo ""
          echo -e "${CYAN}🌐 Access URL: ${WHITE}http://$VPS_IP:9999${NC}"
          echo ""
          echo -e "${AMBER}📝 Quick Guide:${NC}"
          echo -e "  1️⃣  Open the URL in your browser"
          echo -e "  2️⃣  Search for '${WHITE}aztec-sequencer${NC}' in the container list"
          echo -e "  3️⃣  Click to view real-time logs"
          echo -e "  4️⃣  Use filters to search specific events"
          echo ""
          echo -e "${CYAN}💡 Pro Tips:${NC}"
          echo -e "  • Use ${WHITE}Ctrl+F${NC} to search within logs"
          echo -e "  • Click the ${WHITE}⚙️ gear icon${NC} for settings"
          echo -e "  • Enable ${WHITE}dark mode${NC} for better visibility"
          echo ""
        else
          echo -e "${CYAN}🚀 Installing Dozzle for the first time...${NC}"
          echo -e "${CYAN}This will give you a beautiful web interface to view logs!${NC}"
          
          # Pull and run Dozzle
          sudo docker pull amir20/dozzle:latest >/dev/null 2>&1
          sudo docker run -d --name dozzle --restart unless-stopped \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -p 9999:8080 amir20/dozzle:latest >/dev/null 2>&1
          
          # Firewall rules
          sudo ufw allow 9999 >/dev/null 2>&1
          sudo ufw reload >/dev/null 2>&1
          
          VPS_IP=$(curl -s ipv4.icanhazip.com)
          echo ""
          echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
          echo -e "${GREEN}║     ✨ DOZZLE SUCCESSFULLY DEPLOYED! ✨    ║${NC}"
          echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
          echo ""
          echo -e "${CYAN}🌐 Access URL: ${WHITE}http://$VPS_IP:9999${NC}"
          echo ""
          echo -e "${AMBER}📝 Quick Guide:${NC}"
          echo -e "  1️⃣  Open the URL in your browser"
          echo -e "  2️⃣  Search for '${WHITE}aztec-sequencer${NC}' in the container list"
          echo -e "  3️⃣  Click to view real-time logs"
          echo -e "  4️⃣  Use filters to search specific events"
          echo ""
          echo -e "${CYAN}💡 Pro Tips:${NC}"
          echo -e "  • Use ${WHITE}Ctrl+F${NC} to search within logs"
          echo -e "  • Click the ${WHITE}⚙️ gear icon${NC} for settings"
          echo -e "  • Enable ${WHITE}dark mode${NC} for better visibility"
          echo ""
        fi
        read -p "Press Enter to continue..."
        ;;

      2)
        echo ""
        echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
        echo -e "${AMBER}          📊 DOZZLE STATUS REPORT${NC}"
        echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
        echo ""
        
        if sudo docker ps --format '{{.Names}}' | grep -q '^dozzle$'; then
          VPS_IP=$(curl -s ipv4.icanhazip.com)
          
          # Get container details
          DOZZLE_STATUS=$(sudo docker ps --filter "name=dozzle" --format "table {{.Status}}" | tail -n 1)
          DOZZLE_IMAGE=$(sudo docker inspect dozzle --format='{{.Config.Image}}' 2>/dev/null)
          
          echo -e "${GREEN}✅ Status: RUNNING${NC}"
          echo -e "${CYAN}📦 Image: ${WHITE}$DOZZLE_IMAGE${NC}"
          echo -e "${CYAN}⏱️ Uptime: ${WHITE}$DOZZLE_STATUS${NC}"
          echo ""
          echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
          echo ""
          echo -e "${CYAN}🌟 Your Dozzle Dashboard is Ready!${NC}"
          echo ""
          echo -e "  🔗 ${WHITE}Access Link:${NC} ${GREEN}http://$VPS_IP:9999${NC}"
          echo ""
          echo -e "${AMBER}📖 How to Use Dozzle:${NC}"
          echo ""
          echo -e "  ${CYAN}Step 1:${NC} Open the link above in your browser"
          echo -e "  ${CYAN}Step 2:${NC} You'll see all running containers"
          echo -e "  ${CYAN}Step 3:${NC} Click on '${WHITE}aztec-sequencer${NC}' container"
          echo -e "  ${CYAN}Step 4:${NC} Watch your node logs in real-time! 🎯"
          echo ""
          echo -e "${YELLOW}🎨 Fun Features to Try:${NC}"
          echo -e "  • ${WHITE}Split View:${NC} Compare logs from multiple containers"
          echo -e "  • ${WHITE}Filters:${NC} Search for errors, warnings, or specific events"
          echo -e "  • ${WHITE}Download:${NC} Export logs for offline analysis"
          echo -e "  • ${WHITE}Stats:${NC} View container resource usage"
          echo ""
          echo -e "${GREEN}💝 Enjoy your beautiful log viewer!${NC}"
        else
          echo -e "${RED}❌ Status: NOT RUNNING${NC}"
          echo ""
          echo -e "${YELLOW}Dozzle is not currently installed or running.${NC}"
          echo -e "${CYAN}Select option 1 to install it.${NC}"
        fi
        echo ""
        echo -e "${AMBER}═══════════════════════════════════════════════${NC}"
        read -p "Press Enter to continue..."
        ;;

      3)
        echo ""
        if sudo docker ps -a --format '{{.Names}}' | grep -q '^dozzle$'; then
          echo -e "${YELLOW}⚠️  Warning: This will remove Dozzle log viewer${NC}"
          echo -e "${CYAN}Your Aztec node will continue running normally.${NC}"
          echo ""
          read -p "Are you sure you want to remove Dozzle? (Y/n): " confirm
          if [[ "$confirm" =~ ^[Yy]$ || -z "$confirm" ]]; then
            echo -e "${CYAN}Removing Dozzle...${NC}"
            sudo docker stop dozzle >/dev/null 2>&1
            sudo docker rm dozzle >/dev/null 2>&1
            sudo docker rmi amir20/dozzle:latest >/dev/null 2>&1
            echo -e "${GREEN}✅ Dozzle has been removed successfully${NC}"
            echo -e "${CYAN}You can reinstall it anytime from option 1${NC}"
          else
            echo -e "${GREEN}✅ Cancelled - Dozzle remains installed${NC}"
          fi
        else
          echo -e "${YELLOW}Dozzle is not installed${NC}"
        fi
        read -p "Press Enter to continue..."
        ;;

      4)
        break
        ;;
        
      *)
        echo -e "${RED}Invalid choice. Please try again.${NC}"
        sleep 1
        ;;
    esac
  done
}

# ───[ CHECK NODE VERSION ]───
check_node_version() {
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  echo -e "${AMBER}Checking Aztec node version...${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  if sudo docker ps --format '{{.Names}}' | grep -q '^aztec-sequencer$'; then
    VERSION=$(sudo docker inspect aztec-sequencer --format='{{.Config.Image}}' | cut -d: -f2)
    echo -e "${GREEN}✅ Current version: $VERSION${NC}"
    
    # Also try to get version from the container itself
    echo -e "${AMBER}Detailed version info:${NC}"
    sudo docker exec aztec-sequencer node --version 2>/dev/null || echo "Version command not available"
  else
    echo -e "${RED}❌ Node is not running${NC}"
  fi
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
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
  echo -e "${CYAN}12) Launch Dozzle (View Logs in Browser)${NC}"
  echo -e "${CYAN}13) Exit${NC}"
  echo ""
  read -p "Choose option (1-13): " choice

  case $choice in
    1) install_aztec_node ;;
    2) 
      cd ~/aztec && sudo docker compose up -d 
      echo -e "${GREEN}✅ Node started successfully${NC}"
      read -p "Press Enter to continue..."
      ;;
    3) cd ~/aztec && sudo docker compose logs -f ;;
    4)
      echo "--- Current .env ---"
      cat ~/aztec/.env 2>/dev/null || echo ".env file not found!"
      echo ""
      read -p "➡ Do you want to edit values? (Y/n): " edit_choice
      if [[ "$edit_choice" =~ ^[Yy]$ || -z "$edit_choice" ]]; then
        read -p "➡ Enter new Sepolia RPC URL: " ETH_RPC
        read -p "➡ Enter new Beacon RPC URL: " BEACON_RPC
        read -p "➡ Enter new Validator Private Key: " VAL_PRIV
        read -p "➡ Enter new Wallet Address: " WALLET_ADDR
        
        # Auto add 0x prefix if missing
        if [[ ! "$VAL_PRIV" =~ ^0x ]]; then
          VAL_PRIV="0x$VAL_PRIV"
          echo "✅ Auto-added 0x prefix to private key"
        else
          echo "✅ Private key already has 0x prefix"
        fi
        
        if [[ ! "$WALLET_ADDR" =~ ^0x ]]; then
          WALLET_ADDR="0x$WALLET_ADDR"
          echo "✅ Auto-added 0x prefix to wallet address"
        else
          echo "✅ Wallet address already has 0x prefix"
        fi
        
        VPS_IP=$(curl -s ipv4.icanhazip.com)
        cat > ~/aztec/.env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF
        echo "✅ .env updated. Restarting node..."
        cd ~/aztec && sudo docker compose down && sudo docker compose up -d
      fi
      read -p "Press Enter to continue..."
      ;;
    5) 
      check_rpc_health 
      ;;
    6)
      echo -e "${RED}⚠️ This will delete your Aztec Node:${NC}"
      echo "   - ~/aztec"
      echo "   - ~/.aztec/testnet"
      echo "   - Docker container: aztec-sequencer"
      read -p "➡ Are you sure? (Y/n): " confirm1
      if [[ "$confirm1" =~ ^[Yy]$ || -z "$confirm1" ]]; then
        read -p "➡ Are you REALLY sure? This cannot be undone. (Y/n): " confirm2
        if [[ "$confirm2" =~ ^[Yy]$ || -z "$confirm2" ]]; then
          sudo docker stop aztec-sequencer 2>/dev/null
          sudo docker rm aztec-sequencer 2>/dev/null
          # Delete all aztec images regardless of version
          AZTEC_IMAGES=$(sudo docker images aztecprotocol/aztec -q 2>/dev/null)
          if [ -n "$AZTEC_IMAGES" ]; then
            sudo docker rmi -f $AZTEC_IMAGES 2>/dev/null
          fi
          rm -rf ~/aztec ~/.aztec/testnet
          echo "✅ Node deleted."
        else
          echo "❌ Second confirmation failed. Cancelled."
        fi
      else
        echo "❌ Delete cancelled."
      fi
      read -p "Press Enter to continue..."
      ;;
    7) 
      check_ports_and_peerid 
      read -p "Press Enter to continue..."
      ;;
    8) 
      echo -e "${CYAN}Updating Aztec node from 2.0.2 to 2.0.3...${NC}"
      
      # Navigate to aztec directory
      [ "${PWD##*/}" != "aztec" ] && cd ~/aztec
      
      # Run cleanup script
      echo "Running cleanup script..."
      bash <(curl -Ls https://raw.githubusercontent.com/DeepPatel2412/Aztec-Tools/refs/heads/main/Aztec%20CLI%20Cleanup)
      
      # Update docker-compose.yml to version 2.0.3
      echo "Updating docker-compose.yml to version 2.0.3..."
      sed -i 's|^ *image: aztecprotocol/aztec:.*|    image: aztecprotocol/aztec:2.0.3|' docker-compose.yml
      sed -i 's|alpha-testnet|testnet|g' docker-compose.yml
      
      # Restart container with new version
      echo "Restarting node with version 2.0.3..."
      sudo docker compose up -d
      
      echo -e "${GREEN}✅ Node successfully updated to version 2.0.3${NC}"
      read -p "Press Enter to continue..."
      ;;
    9) 
      check_node_version
      read -p "Press Enter to continue..."
      ;;
    10) 
      check_node_performance 
      read -p "Press Enter to continue..."
      ;;
    11) 
      show_running_docker_containers 
      read -p "Press Enter to continue..."
      ;;
    12) 
      launch_dozzle 
      ;;
    13) 
      echo -e "${GREEN}Goodbye! Thanks for using Aztec Node Guide 👋${NC}"
      exit 0 
      ;;
    *) 
      echo -e "${RED}Invalid option. Please try again.${NC}"
      sleep 2
      ;;
  esac
done
  
