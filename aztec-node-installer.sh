#!/bin/bash
set -u   # Exit on undefined variables

# ──────────────[ COLORS ]──────────────
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
ORANGE='\033[1;33m'
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
  echo -e "${CYAN}Updating system...${NC}"
  sudo apt-get update && sudo apt-get upgrade -y

  # Step 3: Install prerequisites
  echo -e "${CYAN}Installing prerequisites...${NC}"
  sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
    tar clang bsdmainutils ncdu unzip ufw screen gawk netcat-openbsd sysstat ifstat
  echo -e "${GREEN}✅ Prerequisites installed${NC}"

  # Step 4: Docker check (SAFE - doesn't reinstall)
  if [ ! -f /etc/os-release ]; then
    echo "Not Ubuntu or Debian"
    exit 1
  fi

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    # Docker NOT installed - install it
    echo -e "${CYAN}Docker not found. Installing Docker...${NC}"
    
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    . /etc/os-release
    repo_url="https://download.docker.com/linux/$ID"
    curl -fsSL "$repo_url/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $repo_url $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Test Docker installation
    if sudo docker run hello-world &>/dev/null; then
      sudo docker rm $(sudo docker ps -a --filter "ancestor=hello-world" --format "{{.ID}}") --force 2>/dev/null || true
      sudo docker image rm hello-world 2>/dev/null || true
    fi
    
    sudo systemctl enable docker
    sudo systemctl restart docker
    echo -e "${GREEN}✅ Docker installed successfully${NC}"
  else
    # Docker IS installed - just skip
    echo -e "${GREEN}✅ Docker already installed: $(docker --version)${NC}"
  fi

  # Add user to docker group
  sudo usermod -aG docker $USER

  # Step 5: Check for ONLY Aztec containers/images
  echo -e "${CYAN}Checking for existing Aztec setup...${NC}"
  
  AZTEC_CONTAINERS=$(sudo docker ps -aq --filter ancestor=aztecprotocol/aztec 2>/dev/null)
  AZTEC_NAMED=$(sudo docker ps -a --format "{{.ID}} {{.Names}}" 2>/dev/null | grep -i "aztec" | awk '{print $1}')
  AZTEC_IMAGES=$(sudo docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" 2>/dev/null | grep "aztecprotocol/aztec" | awk '{print $2}')

  if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED" ] || [ -n "$AZTEC_IMAGES" ]; then
    echo -e "${YELLOW}⚠️  Existing Aztec setup detected!${NC}"
    echo ""
    echo -e "${CYAN}The following will be removed:${NC}"
    if [ -n "$AZTEC_CONTAINERS" ] || [ -n "$AZTEC_NAMED" ]; then
      echo -e "${YELLOW}Containers:${NC}"
      sudo docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | grep -i "aztec"
    fi
    if [ -n "$AZTEC_IMAGES" ]; then
      echo -e "${YELLOW}Images:${NC}"
      sudo docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null | grep "aztecprotocol/aztec"
    fi
    echo ""
    
    read -p "➡ Remove ONLY Aztec containers/images? (y/N): " del_choice
    
    if [[ "$del_choice" =~ ^[Yy]$ ]]; then
      if [ -n "$AZTEC_CONTAINERS" ]; then
        echo "Stopping Aztec containers..."
        echo "$AZTEC_CONTAINERS" | xargs -r sudo docker stop 2>/dev/null || true
        echo "$AZTEC_CONTAINERS" | xargs -r sudo docker rm 2>/dev/null || true
      fi
      
      if [ -n "$AZTEC_NAMED" ]; then
        echo "Stopping named Aztec containers..."
        echo "$AZTEC_NAMED" | xargs -r sudo docker stop 2>/dev/null || true
        echo "$AZTEC_NAMED" | xargs -r sudo docker rm 2>/dev/null || true
      fi
      
      if [ -n "$AZTEC_IMAGES" ]; then
        echo "Removing Aztec images..."
        echo "$AZTEC_IMAGES" | xargs -r sudo docker rmi -f 2>/dev/null || true
      fi
      
      rm -rf ~/aztec ~/.aztec
      echo -e "${GREEN}✅ ONLY Aztec removed (RPC and other containers safe)${NC}"
    else
      echo -e "${RED}❌ Installation cancelled${NC}"
      return
    fi
  fi

  # Step 6: Firewall setup
  echo -e "${CYAN}Configuring firewall...${NC}"
  sudo apt install -y ufw >/dev/null 2>&1
  sudo ufw allow 22
  sudo ufw allow ssh
  sudo ufw allow 40400/tcp
  sudo ufw allow 40400/udp
  sudo ufw allow 8080
  echo "y" | sudo ufw enable 2>/dev/null || sudo ufw --force enable
  sudo ufw reload
  echo -e "${GREEN}✅ Firewall configured${NC}"

  # Step 7: Setup directory
  mkdir -p ~/aztec && cd ~/aztec

  # Step 8: Get configuration with AUTO 0x PREFIX
  echo -e "${CYAN}Configuring your Aztec node...${NC}"

  VPS_IP=$(curl -s ipv4.icanhazip.com)
  echo -e "${GREEN}➡ Auto-detected VPS IP: $VPS_IP${NC}"
  echo ""

  read -p "➡ Enter Sepolia RPC URL: " ETH_RPC
  read -p "➡ Enter Beacon RPC URL: " BEACON_RPC
  read -p "➡ Enter Validator Private Key: " VAL_PRIV_INPUT
  read -p "➡ Enter Wallet Address: " WALLET_ADDR_INPUT

  # Auto-add 0x prefix if not present
  if [[ ! "$VAL_PRIV_INPUT" =~ ^0x ]]; then
    VAL_PRIV="0x${VAL_PRIV_INPUT}"
    echo -e "${YELLOW}ℹ️  Added '0x' prefix to private key${NC}"
  else
    VAL_PRIV="$VAL_PRIV_INPUT"
  fi

  if [[ ! "$WALLET_ADDR_INPUT" =~ ^0x ]]; then
    WALLET_ADDR="0x${WALLET_ADDR_INPUT}"
    echo -e "${YELLOW}ℹ️  Added '0x' prefix to wallet address${NC}"
  else
    WALLET_ADDR="$WALLET_ADDR_INPUT"
  fi

  # Show configuration summary
  echo ""
  echo -e "${CYAN}Configuration Summary:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${WHITE}VPS IP:${NC} $VPS_IP"
  echo -e "${WHITE}Private Key:${NC} ${VAL_PRIV:0:10}...${VAL_PRIV: -4}"
  echo -e "${WHITE}Wallet Address:${NC} $WALLET_ADDR"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  read -p "➡ Is this correct? (Y/n): " confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${RED}❌ Configuration cancelled. Please restart installation.${NC}"
    return
  fi

  # Create .env file
  cat > .env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF

  echo -e "${GREEN}✅ .env file created${NC}"

  # Step 9: Create docker-compose.yml
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

  # Step 10: Start node
  echo -e "${CYAN}Starting Aztec node...${NC}"
  sudo docker compose -f ~/aztec/docker-compose.yml up -d
  
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Installation Complete! 🚀        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Next Steps:${NC}"
echo "   • Use option 2 to view logs"
echo "   • Use option 6 to check ports & peer ID"
echo ""
}

# ───[ RPC HEALTH CHECK ]───
check_rpc_health() {
  bash <(curl -fsSL "https://raw.githubusercontent.com/SpeedoWeb3/Testing/refs/heads/main/check_rpc_health")
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
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y sysstat ifstat >/dev/null 2>&1
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
    echo -e "${RED}Network tools installation failed.${NC}"
  fi

  # Docker stats
echo ""
echo -e "${CYAN}🐳 Docker Container Usage:${NC}"
if command -v docker &>/dev/null; then
  sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
else
  echo -e "${YELLOW}Docker not installed.${NC}"
fi

echo ""
echo -e "${GREEN}✅ Performance check complete!${NC}"
echo -e "${CYAN}─────────────────────────────────────────────${NC}"
}
# ───[ PORT & PEER ID CHECK ]───
check_ports_and_peerid() {
  clear
  bash <(curl -fsSL "https://raw.githubusercontent.com/SpeedoWeb3/Testing/refs/heads/main/Port_cheaker.sh")
}

# ───[ SHOW RUNNING DOCKER CONTAINERS ]───
show_running_docker_containers() {
  echo ""
  echo -e "${ORANGE}🐳  Running Docker Containers${NC}"
  echo -e "${AMBER}────────────────────────────────────────────${NC}"
  echo ""

  # Ensure port checking tools exist
  if ! command -v ss &>/dev/null && ! command -v netstat &>/dev/null; then
    echo -e "${AMBER}Installing network tools...${NC}"
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y net-tools >/dev/null 2>&1
  fi

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

      echo -e "${WHITE}Docker Name${AMBER}  :${NC} ${ORANGE}$NAME${NC}"
      echo -e "${WHITE}Image${AMBER}        :${NC} ${ORANGE}$IMAGE${NC}"
      echo -e "${WHITE}Status${AMBER}       :${NC} ${ORANGE}${STATUS^}${NC}"
      echo -e "${WHITE}Network${AMBER}      :${NC} ${ORANGE}$NETWORK_MODE${NC}"
      echo -e "${WHITE}Uptime${AMBER}       :${NC} ${ORANGE}$UPTIME_FMT${NC}"

      if [ -n "$PORTS" ]; then
        echo -e "${WHITE}Ports${AMBER}        :${NC} ${ORANGE}$PORTS${NC}"
      else
        echo -e "${WHITE}Ports${AMBER}        :${NC} None"
      fi

      echo -e "${AMBER}────────────────────────────────────────────${NC}"
    done

    COUNT=$(echo "$CONTAINERS" | wc -w)
    echo ""
    echo -e "📦 ${WHITE}Total running containers${AMBER}:${NC} ${ORANGE}$COUNT${NC}"
  fi

  echo ""
}

# ───[ DOZZLE MANAGER ]───
launch_dozzle() {
  echo -e "${CYAN}Launching Advanced Dozzle Manager...${NC}"
  bash <(curl -s https://raw.githubusercontent.com/SpeedoWeb3/Testing/refs/heads/main/Dozzle%20manager)
}

# ──────────────[ MAIN MENU ]──────────────
while true; do
  show_header
  echo ""
  echo -e "${CYAN}1) Full Install${NC}"
  echo -e "${CYAN}2) View Logs${NC}"
  echo -e "${CYAN}3) View & Reconfigure .env${NC}"
  echo -e "${CYAN}4) Check RPC Health${NC}"
  echo -e "${CYAN}5) Delete Node${NC}"
  echo -e "${CYAN}6) Check Ports & Peer ID${NC}"
  echo -e "${CYAN}7) Update Node${NC}"
  echo -e "${CYAN}8) Check Node Version${NC}"
  echo -e "${CYAN}9) Check Node Performance${NC}"
  echo -e "${CYAN}10) Show Running Docker Containers${NC}"
  echo -e "${CYAN}11) Launch Dozzle (View Logs in Browser)${NC}"
  echo -e "${CYAN}12) Exit${NC}"
  echo ""
  read -p "Choose option (1-12): " choice

  case $choice in
    1) 
      install_aztec_node 
      ;;
      
    2) 
      cd ~/aztec && sudo docker compose logs -f 
      ;;
      
    3)
      echo -e "${CYAN}───────────────────────────────────────────────${NC}"
      echo -e "${CYAN}Current .env Configuration:${NC}"
      echo -e "${CYAN}───────────────────────────────────────────────${NC}"
      if [ -f ~/aztec/.env ]; then
        cat ~/aztec/.env
      else
        echo -e "${RED}⚠️ .env file not found!${NC}"
        read -p "Press Enter to continue..."
        continue
      fi
      echo ""
      read -p "➡ Do you want to edit values? (y/N): " edit_choice
      
      if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
        echo ""
        read -p "➡ Enter new Sepolia RPC URL: " ETH_RPC
        read -p "➡ Enter new Beacon RPC URL: " BEACON_RPC
        read -p "➡ Enter new Validator Private Key: " VAL_PRIV_INPUT
        read -p "➡ Enter new Wallet Address: " WALLET_ADDR_INPUT
        
        # Auto-add 0x prefix if not present
        if [[ ! "$VAL_PRIV_INPUT" =~ ^0x ]]; then
          VAL_PRIV="0x${VAL_PRIV_INPUT}"
          echo -e "${YELLOW}ℹ️  Added '0x' prefix to private key${NC}"
        else
          VAL_PRIV="$VAL_PRIV_INPUT"
        fi

        if [[ ! "$WALLET_ADDR_INPUT" =~ ^0x ]]; then
          WALLET_ADDR="0x${WALLET_ADDR_INPUT}"
          echo -e "${YELLOW}ℹ️  Added '0x' prefix to wallet address${NC}"
        else
          WALLET_ADDR="$WALLET_ADDR_INPUT"
        fi
        
        VPS_IP=$(curl -s ipv4.icanhazip.com)
        
        cat > ~/aztec/.env <<EOF
ETHEREUM_RPC_URL=$ETH_RPC
CONSENSUS_BEACON_URL=$BEACON_RPC
VALIDATOR_PRIVATE_KEYS=$VAL_PRIV
COINBASE=$WALLET_ADDR
P2P_IP=$VPS_IP
EOF
        echo ""
        echo -e "${GREEN}✅ .env updated successfully!${NC}"
        echo -e "${CYAN}Restarting node with new configuration...${NC}"
        cd ~/aztec && sudo docker compose down && sudo docker compose up -d
        echo -e "${GREEN}✅ Node restarted!${NC}"
      else
        echo -e "${YELLOW}No changes made.${NC}"
      fi
      ;;
      
    4) 
      check_rpc_health 
      ;;
      
    5)
  echo ""
  echo -e "${RED}╔═══════════════════════════════════════════╗${NC}"
  echo -e "${RED}║    ⚠️  DELETE AZTEC NODE WARNING  ⚠️     ║${NC}"
  echo -e "${RED}╚═══════════════════════════════════════════╝${NC}"
  echo ""
  
  # Detect what will be deleted
  echo -e "${YELLOW}Detecting Aztec components...${NC}"
  echo ""
  echo -e "${YELLOW}This will delete:${NC}"
  echo "   • ~/aztec directory"
  echo "   • ~/.aztec/testnet data"
  
  # Check for Aztec containers
  AZTEC_CONTAINERS=$(sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E 'aztec|sequencer' 2>/dev/null | paste -sd ' ' -)
  if [ ! -z "$AZTEC_CONTAINERS" ]; then
    echo "   • Docker containers: $AZTEC_CONTAINERS"
  fi
  
  # Check for Aztec images
  AZTEC_IMAGES=$(sudo docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep aztec 2>/dev/null | paste -sd ' ' -)
  if [ ! -z "$AZTEC_IMAGES" ]; then
    echo "   • Docker images: $AZTEC_IMAGES"
  fi
  
  echo ""
  echo -e "${GREEN}✅ Other Docker containers will NOT be touched${NC}"
  echo ""
  echo -e "${RED}⚠️  This action cannot be undone${NC}"
  read -p "➡ Are you sure? (y/N): " confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    
    # Progress bar function
    show_progress() {
      echo -ne "\r$1 ["
      for ((i=0; i<$2; i++)); do echo -ne "█"; done
      for ((i=$2; i<10; i++)); do echo -ne "░"; done
      echo -ne "] ${3}%"
      if [ "$3" == "100" ]; then
        echo ""
      fi
    }
    
    # Stop and remove containers
    show_progress "${CYAN}Stopping containers...${NC}" 2 20
    sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E 'aztec|sequencer' 2>/dev/null | xargs -r sudo docker stop >/dev/null 2>&1 || true
    sleep 0.5
    
    show_progress "${CYAN}Removing containers...${NC}" 4 40
    sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E 'aztec|sequencer' 2>/dev/null | xargs -r sudo docker rm >/dev/null 2>&1 || true
    sleep 0.5
    
    # Remove images
    show_progress "${CYAN}Removing images...    ${NC}" 6 60
    sudo docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep aztec 2>/dev/null | xargs -r sudo docker rmi -f >/dev/null 2>&1 || true
    sleep 0.5
    
    # Remove directories
    show_progress "${CYAN}Removing directories...${NC}" 8 80
    rm -rf ~/aztec ~/.aztec/testnet >/dev/null 2>&1 || true
    sleep 0.5
    
    show_progress "${CYAN}Cleaning up...        ${NC}" 10 100
    echo ""
    
    echo -e "${GREEN}✅ Aztec Node completely deleted${NC}"
    echo -e "${GREEN}✅ Other Docker containers remain intact${NC}"
  else
    echo -e "${YELLOW}❌ Delete cancelled${NC}"
  fi
  ;;
      
    6) 
      check_ports_and_peerid 
      ;;
      
    7) 
  echo -e "${CYAN}Updating Aztec Node...${NC}"
  
  cd ~/aztec
  
  # Stop node
  docker compose down
  
  # Update version in docker-compose.yml
  sed -i 's|image: aztecprotocol/aztec:.*|image: aztecprotocol/aztec:2.0.3|' docker-compose.yml
  
  # Pull new image
  docker pull aztecprotocol/aztec:2.0.3
  
  # Remove old Aztec images only
  docker images aztecprotocol/aztec --format "{{.ID}} {{.Tag}}" | grep -v "2.0.3" | awk '{print $1}' | xargs -r docker rmi
  
  # Start with new version
  docker compose up -d
  
  echo -e "${GREEN}✅ Node updated to v2.0.3${NC}"
  read -p "Press Enter to continue..."
  ;;
      
    8) 
      echo -e "${CYAN}Checking Aztec Node Version...${NC}"
      if sudo docker ps --format '{{.Names}}' | grep -q '^aztec-sequencer$'; then
        sudo docker exec aztec-sequencer node /usr/src/yarn-project/aztec/dest/bin/index.js --version
      else
        echo -e "${RED}❌ Aztec container is not running!${NC}"
      fi
      ;;
      
    9) 
      check_node_performance 
      ;;
      
    10) 
      show_running_docker_containers 
      ;;
      
    11) 
      launch_dozzle 
      ;;
      
    12) 
      exit 0
      ;;
      
    *)
      echo -e "${RED}❌ Invalid option. Please choose 1-12.${NC}"
      sleep 2
      ;;
  esac

  echo ""
  read -p "Press Enter to return to main menu..."
done
