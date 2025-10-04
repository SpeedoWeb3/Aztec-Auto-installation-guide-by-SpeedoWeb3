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

  # Step 3: Install prerequisites (includes sysstat and ifstat for network stats)
  sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
    tar clang bsdmainutils ncdu unzip ufw screen gawk netcat-openbsd sysstat ifstat

  # Step 4: Docker setup (safe cleanup only for Aztec)
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

  # Step 7: User config
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

  # Step 9: Start node (NO SNAPSHOT RESTORE)
  sudo docker compose -f ~/aztec/docker-compose.yml up -d
  echo -e "${CYAN}Installation finished 🚀 Use option 3 to view logs.${NC}"
}

# ───[ RPC HEALTH CHECK ]───
check_rpc_health() {
  while true; do
    clear
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    echo -e "${CYAN}--- RPC Health Check ---${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}1) Use RPCs from .env file${NC}"
    echo -e "${CYAN}2) Enter custom Sepolia and Beacon RPC URLs${NC}"
    echo -e "${CYAN}3) Back to Main Menu${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    echo ""
    read -p "$(echo -e "${CYAN}Choose option (1-3): ${NC}")" rpc_option
    case $rpc_option in
      1)
        if [ -f "$HOME/aztec/.env" ]; then
          source "$HOME/aztec/.env"
          SEPOLIA_RPC=$ETHEREUM_RPC_URL
          BEACON_RPC=$CONSENSUS_BEACON_URL
        else
          echo -e "${RED}⚠️ .env not found. Please run Full Install first.${NC}"
          read -p "Press Enter to continue..."
          continue
        fi
        ;;
      2)
        read -p "$(echo -e ${CYAN}➡ Enter Sepolia RPC URL: ${NC})" SEPOLIA_RPC
        read -p "$(echo -e ${CYAN}➡ Enter Beacon RPC URL: ${NC})" BEACON_RPC
        ;;
      3)
        break
        ;;
      *)
        echo -e "${RED}Invalid option. Try again.${NC}"
        sleep 1
        continue
        ;;
    esac

    echo ""
    echo -e "${CYAN}🔎 Checking Sepolia RPC:${NC} $SEPOLIA_RPC"
    if curl -s --max-time 5 "$SEPOLIA_RPC" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Reachable${NC}"
    else
      echo -e "${RED}❌ Not reachable${NC}"
    fi

    echo -e "${CYAN}🔎 Checking Beacon RPC:${NC} $BEACON_RPC"
    if curl -s --max-time 5 "$BEACON_RPC" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Reachable${NC}"
    else
      echo -e "${RED}❌ Not reachable${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
  done
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

  # Network Traffic (auto-installs tools if missing)
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

# ───[ SHOW ONLY RUNNING DOCKER CONTAINERS ]───
show_running_docker_containers() {
  ORANGE='\033[1;33m'   # Neon yellow-orange tone
  AMBER='\033[0;33m'    # Warm orange shade
  WHITE='\033[1;37m'    # For light contrast
  RESET='\033[0m'

  echo ""
  echo -e "${ORANGE}🐳  Running Docker Containers${RESET}"
  echo -e "${AMBER}────────────────────────────────────────────${RESET}"
  echo ""

  # Ensure port checking tools exist
  if ! command -v ss &>/dev/null && ! command -v netstat &>/dev/null; then
    echo -e "${AMBER}Installing missing network tools (net-tools)...${RESET}"
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y net-tools >/dev/null 2>&1
  fi

  CONTAINERS=$(sudo docker ps -q)

  if [ -z "$CONTAINERS" ]; then
    echo -e "${AMBER}⚠️  No containers are currently running.${RESET}"
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

      # Ports (fallback for host network, e.g. aztec-sequencer)
      PORTS=$(sudo docker port "$ID" 2>/dev/null | paste -sd ", " -)
      if [ "$NETWORK_MODE" = "host" ] && [ -z "$PORTS" ]; then
        if command -v ss &>/dev/null; then
          PORTS=$(sudo ss -tulnp 2>/dev/null | grep -E "40400|8080" | awk '{print $5}' | cut -d':' -f2 | sort -u | paste -sd ", " -)
        elif command -v netstat &>/dev/null; then
          PORTS=$(sudo netstat -tulnp 2>/dev/null | grep -E "40400|8080" | awk '{print $4}' | cut -d':' -f2 | sort -u | paste -sd ", " -)
        fi
      fi

      echo -e "${WHITE}Docker Name${AMBER}  :${RESET} ${ORANGE}$NAME${RESET}"
      echo -e "${WHITE}Image${AMBER}        :${RESET} ${ORANGE}$IMAGE${RESET}"
      echo -e "${WHITE}Status${AMBER}       :${RESET} ${ORANGE}${STATUS^}${RESET}"
      echo -e "${WHITE}Network${AMBER}      :${RESET} ${ORANGE}$NETWORK_MODE${RESET}"
      echo -e "${WHITE}Uptime${AMBER}       :${RESET} ${ORANGE}$UPTIME_FMT${RESET}"

      if [ -n "$PORTS" ]; then
        echo -e "${WHITE}Ports${AMBER}        :${RESET} ${ORANGE}$PORTS${RESET}"
      else
        echo -e "${WHITE}Ports${AMBER}        :${RESET} None"
      fi

      echo -e "${AMBER}────────────────────────────────────────────${RESET}"
    done

    COUNT=$(echo "$CONTAINERS" | wc -w)
    echo ""
    echo -e "📦 ${WHITE}Total running containers${AMBER}:${RESET} ${ORANGE}$COUNT${RESET}"
  fi

  echo ""
}
# ───[ DOZZLE MANAGER: INSTALL / SHOW / DELETE ]───
launch_dozzle() {
  while true; do
    clear
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    echo -e "${CYAN}🪩 DOZZLE (Docker Log Viewer) MANAGER${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}1) Install Dozzle${NC}"
    echo -e "${CYAN}2) Show Existing Dozzle${NC}"
    echo -e "${CYAN}3) Delete Dozzle${NC}"
    echo -e "${CYAN}4) Back to Main Menu${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────${NC}"
    read -p "Choose an option (1-4): " dozzle_choice

    case $dozzle_choice in
      1)
        echo "🚀 Installing & Launching Dozzle..."
        sudo docker pull amir20/dozzle:latest >/dev/null 2>&1

        # Stop old Dozzle container if running
        if sudo docker ps -a --format '{{.Names}}' | grep -q '^dozzle$'; then
          echo "⚙️ Removing old Dozzle container..."
          sudo docker stop dozzle >/dev/null 2>&1
          sudo docker rm dozzle >/dev/null 2>&1
        fi

        # Run new container
        sudo docker run -d --name dozzle --restart unless-stopped \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -p 9999:8080 amir20/dozzle:latest >/dev/null 2>&1

        # Firewall rules
        sudo ufw allow 9999 >/dev/null 2>&1
        sudo ufw reload >/dev/null 2>&1

        VPS_IP=$(curl -s ipv4.icanhazip.com)
        echo "✅ Dozzle installed & running!"
        echo "🌐 Open in browser: http://$VPS_IP:9999"
        echo "🔎 Search 'aztec-sequencer' to view node logs."
        read -p "Press Enter to continue..."
        ;;

      2)
        echo "🔎 Checking Dozzle status..."
        if sudo docker ps --format '{{.Names}}' | grep -q '^dozzle$'; then
          VPS_IP=$(curl -s ipv4.icanhazip.com)
          echo "✅ Dozzle is running!"
          echo "🌐 Access it at: http://$VPS_IP:9999"
          echo "🔎 Search 'aztec-sequencer' inside Dozzle to view logs."
        else
          echo "❌ Dozzle is not running."
        fi
        read -p "Press Enter to continue..."
        ;;

      3)
        echo "⚠️ This will delete the Dozzle container completely."
        read -p "Are you sure? (Y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ || -z "$confirm" ]]; then
          sudo docker stop dozzle >/dev/null 2>&1
          sudo docker rm dozzle >/dev/null 2>&1
          echo "✅ Dozzle container deleted."
        else
          echo "❌ Cancelled."
        fi
        read -p "Press Enter to continue..."
        ;;

      4)
        break
        ;;
      *)
        echo "Invalid choice. Try again."
        sleep 1
        ;;
    esac
  done
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
        cd ~/aztec && sudo docker compose up -d
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
    11) show_running_docker_containers ;;
    12) launch_dozzle ;;
    13) echo "Exiting..."; break ;;
  esac

  read -p "Press Enter to continue..."
done
