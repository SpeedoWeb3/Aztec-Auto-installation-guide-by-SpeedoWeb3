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
- ✅ **Minimum 4GB RAM** (8GB recommended)
- ✅ **50GB+ free disk space**
- ✅ **Open ports**: 40400 (TCP/UDP), 8080 (TCP)
- ✅ **curl** installed (`sudo apt install curl -y`)

---

## 🎮 Menu Options

Once you run the installer, you'll see an interactive menu:

```
╔════════════════════════════════════════╗
║     AZTEC NODE MANAGER v1.0           ║
╠════════════════════════════════════════╣
║  1. Install Aztec Node (Full Setup)   ║
║  2. Start/Stop Node                   ║
║  3. View Live Logs                    ║
║  4. Edit Configuration                ║
║  5. RPC Health Check                  ║
║  6. Port & Peer ID Status             ║
║  7. Update Node                       ║
║  8. Delete Node                       ║
║  9. Exit                              ║
╚════════════════════════════════════════╝
```

### 🔹 Option Details

| Option | Function |
|--------|----------|
| **1. Install** | Full installation with snapshot download |
| **2. Start/Stop** | Manage Docker container |
| **3. Logs** | View real-time node logs |
| **4. Config** | Edit `.env` file safely |
| **5. Health Check** | Test RPC endpoint |
| **6. Port Check** | Verify ports & get Peer ID |
| **7. Update** | Pull latest Aztec version |
| **8. Delete** | Remove node (with backup option) |

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

### ❌ Script won't run
```bash
# Install curl
sudo apt update && sudo apt install curl -y

# Run with sudo
sudo bash <(curl -fsSL https://raw.githubusercontent.com/SpeedoWeb3/Aztec-Auto-installation-guide-by-SpeedoWeb3/main/aztec-node-installer.sh)
```

### ❌ Ports showing closed
```bash
# Check firewall
sudo ufw status

# Open required ports
sudo ufw allow 40400/tcp
sudo ufw allow 40400/udp
sudo ufw allow 8080/tcp
sudo ufw reload
```

### ❌ Node not syncing
```bash
# Check logs
docker logs -f aztec-sequencer

# Restart node
docker restart aztec-sequencer
```

### ❌ RPC not responding
```bash
# Test RPC
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"node_getVersion","params":[],"id":1}'
```

---

## 📚 Useful Commands

### Node Management
```bash
# Start node
docker start aztec-sequencer

# Stop node
docker stop aztec-sequencer

# Restart node
docker restart aztec-sequencer

# View logs
docker logs -f aztec-sequencer

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
top
```

---

## 🔗 Useful Links

- 🌐 [Aztec Protocol](https://aztec.network)
- 📖 [Official Documentation](https://docs.aztec.network)
- 💬 [Discord Community](https://discord.gg/aztec)
- 🐦 [Twitter](https://twitter.com/aztecnetwork)
- 🔍 [Nethermind Explorer](https://explorer.aztec.network)

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
