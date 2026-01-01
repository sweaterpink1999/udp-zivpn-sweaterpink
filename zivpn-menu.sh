#!/bin/bash
# ZIVPN Menu - PREMIUM UI (SELF INSTALL & UPDATE)

### ===== PATH & URL =====
MENU_PATH="/usr/bin/zivpn-menu"
MENU_URL="https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh"

CONFIG="/etc/zivpn/config.json"
PORT_RANGE="6000-19999"

### ===== SELF INSTALL MODE =====
if [[ "$0" != "$MENU_PATH" ]]; then
  echo "Installing ZIVPN Menu..."
  cp "$0" "$MENU_PATH"
  chmod +x "$MENU_PATH"

  # auto run menu on SSH login
  if ! grep -q "AUTO ZIVPN MENU" /root/.bashrc 2>/dev/null; then
cat >> /root/.bashrc << 'EOF'

# === AUTO ZIVPN MENU ===
if [[ -n "$SSH_CONNECTION" ]]; then
  if [[ -z "$TMUX" && -z "$SCREEN" ]]; then
    clear
    /usr/bin/zivpn-menu
    exit
  fi
fi
EOF
  fi

  echo "ZIVPN Menu installed."
  echo "Logout & login again."
  exit
fi

### ===== SYSTEM INFO =====
OS=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
IP=$(curl -s ifconfig.me)
UPTIME=$(uptime -p)
CPU=$(nproc)
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
ZIVPN_STATUS=$(systemctl is-active zivpn)

clear
figlet ZIVPN | lolcat
echo " // ZIVPN UDP SERVER //"
echo "--------------------------------------"
echo " OS      : $OS"
echo " IP      : $IP"
echo " Uptime  : $UPTIME"
echo " CPU     : $CPU Cores"
echo " RAM     : $RAM_USED / $RAM_TOTAL MB"
echo " Disk    : $DISK_USED / $DISK_TOTAL"
echo " ZIVPN   : $ZIVPN_STATUS"
echo "--------------------------------------"
echo " 1) Create Account"
echo " 2) Show Active Password"
echo " 3) Restart ZIVPN"
echo " 9) Update Menu"
echo " 0) Exit"
echo "--------------------------------------"
read -p " Select Menu : " opt

case $opt in
1)
read -p " Username (bebas) : " USER
read -p " Duration (days)  : " DAYS

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

sed -i -E 's/"config":[[:space:]]*\[[^]]*\]/"config":["'"$PASS"'"]/' "$CONFIG"
systemctl restart zivpn

clear
echo "===================================="
echo "        ZIVPN UDP ACCOUNT"
echo "===================================="
echo " Server IP        : $IP"
echo " Port Range       : $PORT_RANGE"
echo " User             : $USER"
echo " Password         : $PASS"
echo " Expiration date  : $EXP"
echo "===================================="
read -p "Press Enter..."
exec "$MENU_PATH"
;;

2)
clear
grep -oP '"config":\s*\[\s*"\K[^"]+' "$CONFIG"
read -p "Press Enter..."
exec "$MENU_PATH"
;;

3)
systemctl restart zivpn
sleep 2
exec "$MENU_PATH"
;;

9)
echo "Updating menu..."
curl -fsSL "$MENU_URL" -o "$MENU_PATH"
chmod +x "$MENU_PATH"
exec "$MENU_PATH"
;;

0)
exit
;;
esac
