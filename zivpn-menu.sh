#!/bin/bash
# ZIVPN UDP USER PANEL (USERNAME + EXPIRED)
# SAFE | MULTI USER | UP TO 80 USERS

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

menu() {
clear
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${WHITE}        Z I V P N   U D P   P A N E L${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo " 1) Create Account"
echo " 2) List Accounts"
echo " 3) Delete Account"
echo " 4) Renew Account"
echo " 5) Restart ZIVPN"
echo " 0) Exit"
echo -e "${CYAN}══════════════════════════════════════${NC}"
read -p " Select Menu : " opt
}

list_accounts() {
echo "-------------------------------------------------------------"
printf "%-4s %-15s %-20s %-12s\n" "No" "Username" "Password" "Expired"
echo "-------------------------------------------------------------"
nl -w2 -s'. ' "$DB" | while read n line; do
  USER=$(echo "$line" | cut -d'|' -f1)
  PASS=$(echo "$line" | cut -d'|' -f2)
  EXP=$(echo "$line" | cut -d'|' -f3)
  printf "%-4s %-15s %-20s %-12s\n" "$n" "$USER" "$PASS" "$EXP"
done
echo "-------------------------------------------------------------"
}

create_account() {
read -p " Username : " USER
read -p " Duration (days) : " DAYS

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

COUNT=$(jq '.auth.config | length' "$CONFIG")
[ "$COUNT" -ge 80 ] && echo "Max 80 users reached" && sleep 2 && return

jq --arg pass "$PASS" '.auth.config += [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
echo "$USER|$PASS|$EXP" >> "$DB"

systemctl restart zivpn

echo
echo "ACCOUNT CREATED"
echo " Username : $USER"
echo " Password : $PASS"
echo " Expired  : $EXP"
read -p "Press Enter..."
}

delete_account() {
list_accounts
read -p " Delete number : " NUM

PASS=$(sed -n "${NUM}p" "$DB" | cut -d'|' -f2)

sed -i "${NUM}d" "$DB"
jq --arg pass "$PASS" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"

systemctl restart zivpn
echo "Account deleted"
sleep 2
}

renew_account() {
list_accounts
read -p " Renew number : " NUM

NEWPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(sed -n "${NUM}p" "$DB" | cut -d'|' -f3)

sed -i "${NUM}s|^[^|]*|&|; ${NUM}s|[^|]*|$NEWPASS|2" "$DB"
jq --arg pass "$NEWPASS" ".auth.config[$((NUM-1))] = \$pass" "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"

systemctl restart zivpn
echo "Account renewed"
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
0) exit ;;
*) echo "Invalid"; sleep 1 ;;
esac
done
