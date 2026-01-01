#!/bin/bash
# ZIVPN Menu - COLOR UI (MULTI USER UP TO 80)
# UI TIDAK DIUBAH

CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"
PORT_RANGE="6000-19999"

mkdir -p /etc/zivpn
touch "$DB"

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

menu() {
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
echo -e "${YELLOW} 2${NC}) List Accounts"
echo -e "${YELLOW} 3${NC}) Delete Account"
echo -e "${YELLOW} 4${NC}) Renew Account"
echo -e "${YELLOW} 5${NC}) Restart ZIVPN"
echo -e "${YELLOW} 9${NC}) Update Menu"
echo -e "${RED} 0${NC}) Exit"
echo -e "${CYAN}══════════════════════════════════════${NC}"
read -p " Select Menu : " opt
}

list_accounts() {
echo "-------------------------------------------------------------"
printf "%-4s %-15s %-20s %-12s\n" "No" "Username" "Password" "Expired"
echo "-------------------------------------------------------------"
nl -w2 -s'. ' "$DB" | while read n line; do
  U=$(echo "$line" | cut -d'|' -f1)
  P=$(echo "$line" | cut -d'|' -f2)
  E=$(echo "$line" | cut -d'|' -f3)
  printf "%-4s %-15s %-20s %-12s\n" "$n" "$U" "$P" "$E"
done
echo "-------------------------------------------------------------"
}

create_account() {
read -p " Username : " USER
read -p " Duration (days) : " DAYS

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

COUNT=$(jq '.auth.config | length' "$CONFIG")
[ "$COUNT" -ge 80 ] && echo -e "${RED}Max 80 accounts reached${NC}" && sleep 2 && return

jq --arg pass "$PASS" '.auth.config += [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
echo "$USER|$PASS|$EXP" >> "$DB"

systemctl restart zivpn

clear
echo -e "${GREEN}ACCOUNT CREATED${NC}"
echo " Username : $USER"
echo " Password : $PASS"
echo " Expired  : $EXP"
read -p "Press Enter..."
}

delete_account() {
clear
list_accounts
read -p " Delete number : " NUM

PASS=$(sed -n "${NUM}p" "$DB" | cut -d'|' -f2)

sed -i "${NUM}d" "$DB"
jq --arg pass "$PASS" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"

systemctl restart zivpn
echo -e "${GREEN}Account deleted${NC}"
sleep 2
}

renew_account() {
clear
list_accounts
read -p " Renew number : " NUM

NEWPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
USER=$(sed -n "${NUM}p" "$DB" | cut -d'|' -f1)
EXP=$(sed -n "${NUM}p" "$DB" | cut -d'|' -f3)

sed -i "${NUM}c\\$USER|$NEWPASS|$EXP" "$DB"
jq --arg pass "$NEWPASS" ".auth.config[$((NUM-1))] = \$pass" "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"

systemctl restart zivpn
echo -e "${GREEN}Account renewed${NC}"
echo " New Password : $NEWPASS"
read -p "Press Enter..."
}

while true; do
menu
case $opt in
1) create_account ;;
2) clear; list_accounts; read -p "Press Enter..." ;;
3) delete_account ;;
4) renew_account ;;
5) systemctl restart zivpn ;;
9)
curl -fsSL https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh -o /usr/bin/zivpn-menu
chmod +x /usr/bin/zivpn-menu
exec /usr/bin/zivpn-menu
;;
0) exit ;;
*) echo "Invalid"; sleep 1 ;;
esac
done
