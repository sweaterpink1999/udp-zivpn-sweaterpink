#!/bin/bash
set +e
# ZIVPN Menu - COLOR UI (MULTI USER)
# READY FOR SELLING | NO AUTO BLOCK

CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"
DOMAIN_FILE="/etc/zivpn/domain.conf"

mkdir -p /etc/zivpn
touch "$DB"
[ ! -f "$DOMAIN_FILE" ] && echo "-" > "$DOMAIN_FILE"

DOMAIN=$(cat "$DOMAIN_FILE")

# ===== ENSURE JQ =====
if ! command -v jq >/dev/null 2>&1; then
  apt update -y >/dev/null 2>&1
  apt install -y jq >/dev/null 2>&1
fi

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
ZIVPN_STATUS=$(systemctl is-active zivpn 2>/dev/null)
USER_COUNT=$(grep -c '|' "$DB" 2>/dev/null)

menu() {
clear
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${WHITE}        Z I V P N   U D P   M E N U${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${GREEN} OS      ${NC}: $OS"
echo -e "${GREEN} Domain  ${NC}: ${YELLOW}$DOMAIN${NC}"
echo -e "${GREEN} IP      ${NC}: $IP"
echo -e "${GREEN} Uptime  ${NC}: $UPTIME"
echo -e "${GREEN} CPU     ${NC}: $CPU Cores"
echo -e "${GREEN} RAM     ${NC}: $RAM_USED / $RAM_TOTAL MB"
echo -e "${GREEN} Disk    ${NC}: $DISK_USED / $DISK_TOTAL"
echo -e "${GREEN} ZIVPN   ${NC}: ${YELLOW}$ZIVPN_STATUS${NC}"
echo -e "${GREEN} Users   ${NC}: ${YELLOW}$USER_COUNT${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${YELLOW} 1${NC}) Create Account"
echo -e "${YELLOW} 2${NC}) List Accounts"
echo -e "${YELLOW} 3${NC}) Delete Account (Number / Password)"
echo -e "${YELLOW} 4${NC}) Renew Account"
echo -e "${YELLOW} 5${NC}) Restart ZIVPN"
echo -e "${YELLOW} 6${NC}) Delete All Expired Accounts"
echo -e "${YELLOW} 7${NC}) Check User Usage (IP Monitor)"
echo -e "${YELLOW} 8${NC}) Change Domain"
echo -e "${YELLOW} 9${NC}) Update Menu"
echo -e "${YELLOW}10${NC}) Create Trial (Minutes)"
echo -e "${RED} 0${NC}) Exit"
echo -e "${CYAN}══════════════════════════════════════${NC}"
read -rp " Select Menu : " opt
}

list_accounts() {
clear
echo "--------------------------------------------------------------------------"
printf "%-4s %-15s %-18s %-16s %-8s\n" "No" "Username" "Password" "Expired" "Limit"
echo "--------------------------------------------------------------------------"
nl -w2 -s'. ' "$DB" | while read -r n l; do
  IFS='|' read -r U P E L <<< "$l"
  [ -z "$L" ] && L="∞"
  printf "%-4s %-15s %-18s %-16s %-8s\n" "$n" "$U" "$P" "$E" "$L"
done
echo "--------------------------------------------------------------------------"
}

create_account() {
read -rp " Username : " USER
read -rp " Duration (days) : " DAYS
read -rp " IP Limit (1/2/3, 0=unlimit) : " LIMIT
[ "$LIMIT" = "0" ] && LIMIT="∞"

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

jq --arg pass "$PASS" '.auth.config += [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
echo "$USER|$PASS|$EXP|$LIMIT" >> "$DB"
systemctl restart zivpn

clear
echo -e "${GREEN}ACCOUNT CREATED${NC}"
echo " Domain   : $DOMAIN"
echo " Username : $USER"
echo " Password : $PASS"
echo " Expired  : $EXP"
echo " IP Limit : $LIMIT"
read -p "Press Enter..."
}

# ===== MENU 10: TRIAL PER MENIT =====
create_trial() {
read -rp " Trial duration (minutes): " MIN
[[ -z "$MIN" || "$MIN" -le 0 ]] && return

USER="trial$(tr -dc 0-9 </dev/urandom | head -c 4)"
PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
EXP=$(date -d "+$MIN minutes" +"%Y-%m-%d %H:%M")
LIMIT=1

jq --arg pass "$PASS" '.auth.config += [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
echo "$USER|$PASS|$EXP|$LIMIT" >> "$DB"
systemctl restart zivpn

clear
echo -e "${GREEN}TRIAL CREATED${NC}"
echo " Domain   : $DOMAIN"
echo " Username : $USER"
echo " Password : $PASS"
echo " Expired  : $EXP"
echo " Limit IP : 1"
read -p "Press Enter..."
}

change_domain() {
read -rp " New Domain : " NEWDOMAIN
[ -z "$NEWDOMAIN" ] && return
echo "$NEWDOMAIN" > "$DOMAIN_FILE"

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/C=ID/ST=VPN/L=ZIVPN/O=ZIVPN/OU=ZIVPN/CN=$NEWDOMAIN" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt 2>/dev/null

systemctl restart zivpn
DOMAIN="$NEWDOMAIN"
echo -e "${GREEN}Domain updated successfully${NC}"
sleep 2
}

ip_monitor() {
clear
echo "USER USAGE MONITOR"
echo "--------------------------------------------------"
printf "%-10s %-18s %-8s %-10s\n" "Username" "Password" "Limit" "Status"
echo "--------------------------------------------------"

# hitung total IP aktif server
TOTAL_IP=$(ss -u -n state connected '( sport = :5667 )' | wc -l)

while IFS='|' read -r U P E L; do
  [ -z "$L" ] && L="∞"

  # cek apakah ADA koneksi UDP sama sekali
  if [ "$TOTAL_IP" -gt 0 ]; then
    STATUS="ONLINE"
  else
    STATUS="OFFLINE"
  fi

  printf "%-10s %-18s %-8s %-10s\n" "$U" "$P" "$L" "$STATUS"
done < "$DB"

echo "--------------------------------------------------"
echo "Total IP Active (Server): $TOTAL_IP"
read -p "Press Enter..."
}

renew_account() {
list_accounts
echo
read -rp " Renew account number : " NUM
read -rp " Extend days : " DAYS

LINE=$(sed -n "${NUM}p" "$DB")
[ -z "$LINE" ] && echo "Invalid number" && sleep 2 && return

IFS='|' read -r U P E L <<< "$LINE"

# jika expired pakai jam, buang jam
BASE_DATE=$(echo "$E" | cut -d' ' -f1)
NEWEXP=$(date -d "$BASE_DATE +$DAYS days" +"%Y-%m-%d")

sed -i "${NUM}c\\$U|$P|$NEWEXP|$L" "$DB"
systemctl restart zivpn

echo -e "${GREEN}Account renewed successfully${NC}"
sleep 2
}

delete_all_expired() {
NOW=$(date +"%Y-%m-%d %H:%M")
TMP="/tmp/zivpn-clean.db"
> "$TMP"

while IFS='|' read -r U P E L; do
  if [[ "$E" < "$NOW" ]]; then
    jq --arg pass "$P" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
  else
    echo "$U|$P|$E|$L" >> "$TMP"
  fi
done < "$DB"

mv "$TMP" "$DB"
systemctl restart zivpn

echo -e "${GREEN}Expired accounts deleted${NC}"
sleep 2
}

restart_zivpn() {
systemctl restart zivpn
echo -e "${GREEN}ZIVPN restarted successfully${NC}"
sleep 2
}

delete_account() {
list_accounts
echo
echo "DELETE ACCOUNT"
echo "--------------------------------------------------"
echo "• Input NUMBER (1,2,3)"
echo "• Atau input PASSWORD langsung"
echo "--------------------------------------------------"
read -rp " Input : " INPUT

if [[ "$INPUT" =~ ^[0-9]+$ ]]; then
  LINE=$(sed -n "${INPUT}p" "$DB")
  [ -z "$LINE" ] && echo "Invalid number" && sleep 2 && return
  PASS=$(echo "$LINE" | cut -d'|' -f2)
  sed -i "${INPUT}d" "$DB"
else
  PASS="$INPUT"
  grep -q "|$PASS|" "$DB" || { echo "Password not found"; sleep 2; return; }
  sed -i "\|$PASS|d" "$DB"
fi

jq --arg pass "$PASS" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
systemctl restart zivpn
echo -e "${GREEN}Account deleted successfully${NC}"
sleep 2
}

while true; do
menu
case $opt in
1) create_account ;;
2) list_accounts; read -p "Press Enter..." ;;
3) delete_account ;;
4) renew_account ;;
5) restart_zivpn ;;
6) delete_all_expired ;;
7) ip_monitor ;;
8) change_domain ;;
9)
curl -fsSL https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh -o /usr/bin/zivpn-menu
chmod +x /usr/bin/zivpn-menu
exec bash /usr/bin/zivpn-menu
;;
10) create_trial ;;
0) exit ;;
esac
done
