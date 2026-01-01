#!/bin/bash
# ZIVPN Menu - COLOR UI (MULTI PASSWORD)

CONFIG="/etc/zivpn/config.json"
PORT_RANGE="6000-19999"

# ===== COLORS =====
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

IP=$(curl -s ifconfig.me)

clear
echo -e "${CYAN}=====================================${NC}"
echo -e "${YELLOW}        ZIVPN UDP MENU (MULTI PASS)${NC}"
echo -e "${CYAN}=====================================${NC}"
echo "1) Create Account (ADD Password)"
echo "2) Show All Password"
echo "3) Restart ZIVPN"
echo "0) Exit"
echo -e "${CYAN}=====================================${NC}"
read -p "Select Menu : " opt

case $opt in

1)
read -p " Duration (days) : " DAYS
PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

# ambil password lama
OLD_PASS=$(grep -oP '"config":\s*\[\K[^\]]*' "$CONFIG")

if [[ -z "$OLD_PASS" ]]; then
  NEW_LIST="\"$PASS\""
else
  NEW_LIST="$OLD_PASS,\"$PASS\""
fi

# update config.json
sed -i -E "s/\"config\":\s*\[[^\]]*\]/\"config\": [$NEW_LIST]/" "$CONFIG"

systemctl restart zivpn

clear
echo -e "${CYAN}=====================================${NC}"
echo -e "${GREEN}      ZIVPN UDP ACCOUNT CREATED${NC}"
echo -e "${CYAN}=====================================${NC}"
echo " Server IP     : $IP"
echo " Port Range    : $PORT_RANGE"
echo " Password      : $PASS"
echo " Expired       : $EXP"
echo -e "${CYAN}=====================================${NC}"
read -p "Press Enter..."
exec "$0"
;;

2)
clear
echo -e "${WHITE}Active Passwords:${NC}"
echo "--------------------------"

# ambil semua password
PASS_LIST=$(grep -oP '"config":\s*\[\K[^\]]*' "$CONFIG" | tr ',' '\n' | tr -d '"')

if [ -z "$PASS_LIST" ]; then
  echo "No active password"
else
  echo "$PASS_LIST"
fi

echo "--------------------------"
read -p " Press Enter to return menu..."
exec "$0"
;;


3)
systemctl restart zivpn
echo -e "${GREEN}ZIVPN restarted${NC}"
sleep 2
exec "$0"
;;

0)
exit
;;

*)
echo -e "${RED}Invalid option${NC}"
sleep 1
exec "$0"
;;
esac
