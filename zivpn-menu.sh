#!/bin/bash
# ZIVPN Menu - COLOR UI (NO DEPENDENCY, SAFE)
# MULTI PASSWORD VERSION (UP TO 80 PASS) - FIXED

CONFIG="/etc/zivpn/config.json"
PORT_RANGE="6000-19999"

# ===== COLORS =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ===== SYSTEM INFO =====
OS=$(lsb_release -ds 2>/dev/null | tr -d '"')
IP=$(curl -s ifconfig.me)
UPTIME=$(uptime -p)
CPU=$(nproc)
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
ZIVPN_STATUS=$(systemctl is-active zivpn)

clear
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${WHITE}        Z I V P N   U D P   M E N U${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${GREEN} OS      ${NC}: $OS"
echo -e "${GREEN} IP      ${NC}: $IP"
echo -e "${GREEN} Uptime  ${NC}: $UPTIME"
echo -e "${GREEN} CPU     ${NC}: $CPU Cores"
echo -e "${GREEN} RAM     ${NC}: $RAM_USED / $RAM_TOTAL MB"
echo -e "${GREEN} Disk    ${NC}: $DISK_USED / $DISK_TOTAL"
echo -e "${GREEN} ZIVPN   ${NC}: ${YELLOW}$ZIVPN_STATUS${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${YELLOW} 1${NC}) Create Account"
echo -e "${YELLOW} 2${NC}) Show Active Password"
echo -e "${YELLOW} 3${NC}) Restart ZIVPN"
echo -e "${YELLOW} 9${NC}) Update Menu"
echo -e "${RED} 0${NC}) Exit"
echo -e "${CYAN}══════════════════════════════════════${NC}"
read -p " Select Menu : " opt

case $opt in

1)
read -p " Username (bebas) : " USER
read -p " Duration (days)  : " DAYS

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

COUNT=$(jq '.auth.config | length' "$CONFIG")

if [ "$COUNT" -ge 80 ]; then
  echo -e "${RED}Maximum 80 password reached!${NC}"
  sleep 2
  exec "$0"
fi

jq --arg pass "$PASS" '.auth.config += [$pass]' "$CONFIG" > /tmp/zivpn.json \
  && mv /tmp/zivpn.json "$CONFIG"

systemctl restart zivpn

clear
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${WHITE}        ZIVPN UDP ACCOUNT${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e " Server IP        : $IP"
echo -e " Port Range       : $PORT_RANGE"
echo -e " User             : $USER"
echo -e " Password         : ${GREEN}$PASS${NC}"
echo -e " Duration days    : $DAYS"
echo -e " Expiration date  : $EXP"
echo -e "${CYAN}══════════════════════════════════════${NC}"
read -p " Press Enter to return menu..."
exec "$0"
;;

2)
clear
echo -e "${WHITE}Active Password:${NC}"
echo "----------------------------"
jq -r '.auth.config[]' "$CONFIG"
echo "----------------------------"
read -p " Press Enter to return menu..."
exec "$0"
;;

3)
systemctl restart zivpn
echo -e "${GREEN}ZIVPN restarted${NC}"
sleep 2
exec "$0"
;;

9)
curl -fsSL https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh \
  -o /usr/bin/zivpn-menu
chmod +x /usr/bin/zivpn-menu
exec /usr/bin/zivpn-menu
;;

0)
exit
;;
esac
