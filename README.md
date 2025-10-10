# 🚀 Aztec Node Auto-Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Aztec Protocol](https://img.shields.io/badge/Aztec-Protocol-blue)](https://aztec.network)
[![Made by SpeedoWeb3](https://img.shields.io/badge/Made%20by-SpeedoWeb3-cyan)](https://github.com/SpeedoWeb3)

> **Automated installation and management script for running an Aztec Node on your VPS**  
> Simplifies setup, configuration, updates, and monitoring — all from a single interactive menu.

---

## 📌 Features

| Feature | Description |
|---------|-------------|
| 🎯 **Full Install** | Fresh setup with snapshot support |
| 🐳 **Node Management** | Docker-based node control |
| 📊 **Live Logs** | Real-time log monitoring |
| ⚙️ **Config Editor** | Safe `.env` viewing & reconfiguration |
| 🏥 **RPC Health Check** | Based on Catman Creed's guide |
| 🗑️ **Safe Deletion** | Node removal with confirmation |
| 🔍 **Port Checker** | Monitor critical ports & Peer ID |
| 🔗 **Explorer Link** | Direct Nethermind explorer integration |
| 🔄 **Auto Update** | Easy node updates |

---

## ⚡ Quick Start

### 🛠️ One-Command Installation

Run this single command to launch the interactive menu:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SpeedoWeb3/Aztec-Auto-installation-guide-by-SpeedoWeb3/main/aztec-node-installer.sh)
```

---

## 📋 Prerequisites

Before running the installer, ensure you have:

- ✅ **VPS/Server** with Ubuntu 20.04+ or Debian 11+
- ✅ **Root or sudo access**
- ✅ **Minimum 8GB RAM** (16GB recommended)
- ✅ **250GB+ free disk space**
- ✅ **Open ports**: 40400 (TCP/UDP), 8080 (TCP)
- ✅ **curl** installed (`sudo apt install curl -y`)

---

## 🎮 Menu Options

Once you run the installer, you'll see an interactive menu:



### 🔹 Option Details
```
| Option | Function |
|--------|----------|
| **1. Full Install** | Complete installation with snapshot download |
| **2. View Logs** | View real-time node logs in terminal |
| **3. View & Reconfigure .env** | Edit configuration file safely |
| **4. Check RPC Health** | Test RPC endpoint health |
| **5. Delete Node** | Remove node with confirmation |
| **6. Check Ports & Peer ID** | Verify ports & get Peer ID with explorer link |
| **7. Update Node** | Pull latest Aztec version |
| **8. Check Node Version** | Display current node version |
| **9. Check Node Performance** | Full system diagnostics & health check |
| **10. Show Docker Containers** | List all running containers |
| **11. Launch Dozzle** | Web-based log viewer (access at port 9999) |
| **12. Exit** | Close the menu |
```
---


## 🔍 Port Checker Standalone

Want to just check your node status? Use the standalone checker:

```bash
bash <(curl -s https://raw.githubusercontent.com/SpeedoWeb3/Aztec--Status--Checker/refs/heads/main/Performance)
```

**What it checks:**
- ✅ Port 40400/TCP status (Local, Firewall, External)
- ✅ Port 40400/UDP status
- ✅ Port 8080/TCP status (RPC)
- ✅ Docker container health
- ✅ Deployment method detection
- ✅ Network diagnostics

---

## 🆘 Troubleshooting

###  Script won't run
```bash
# Install curl
sudo apt update && sudo apt install curl -y

# Run with sudo
sudo bash <(curl -fsSL https://raw.githubusercontent.com/SpeedoWeb3/Aztec-Auto-installation-guide-by-SpeedoWeb3/main/aztec-node-installer.sh)
```

###  Ports showing closed
```bash
# Check firewall
sudo ufw status

# Open required ports
sudo ufw allow 40400/tcp
sudo ufw allow 40400/udp
sudo ufw allow 8080/tcp
sudo ufw reload
```

### Aztec Node not syncing
```bash
#Go to aztec directory
cd && cd aztec

# Check logs
docker compose logs -100

# Restart node
docker compose down -v && docker compose up -d
```

### Check Rpc Sync Status 
```
curl -X POST -H "Content-Type: application/json" \
--data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
http://localhost:8545
```

### Check Rpc block number
```
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
  ```
---

### Node Management
```
# Go to aztec directory first
cd && cd aztec

# Start node
docker compose up -d 

# Stop node
docker compose down -v

# Restart node
docker compose down -v && docker compose up -d

# View logs
docker compose logs -fn 100

# Check status
docker ps | grep aztec
```

### System Monitoring
```bash
# Check disk usage
df -h

# Check memory
free -h

# Check CPU
htop
```

---

## 🔗 Useful Links

- 🌐 [Aztec Protocol](https://aztec.network)
- 📖 [Official Documentation](https://docs.aztec.network)
- 💬 [Discord Community](https://discord.gg/aztec)
- 🐦 [Twitter](https://twitter.com/aztecnetwork)
- 🔍 [Nethermind Explorer](https://aztec.nethermind.io/)

---

## 🙌 Credits

**Developed by [@SpeedoWeb3](https://github.com/SpeedoWeb3)**

**Special thanks to:**
- @web3.creed
- @web3hendrix
- @assshhh_2127
- Aztec Protocol Community
---

## 🌟 Support the Project

If you find this tool helpful:

- ⭐ **Star this repository**
- 🐛 **Report issues** on GitHub or tag on Aztec Dc
- 💡 **Suggest features** via Issues
- 🔄 **Share** with the community


---

<div align="center">

**Made with ❤️ by [SpeedoWeb3](https://github.com/SpeedoWeb3)**

[![GitHub](https://img.shields.io/badge/GitHub-SpeedoWeb3-black?logo=github)](https://github.com/SpeedoWeb3)
[![Twitter](https://img.shields.io/badge/Twitter-@SpeedoWeb3-blue?logo=twitter)](https://twitter.com/SpeedoWeb3)

**For the Aztec Community 🚀**

</div>
