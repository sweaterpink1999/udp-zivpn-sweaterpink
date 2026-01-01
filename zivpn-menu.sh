#!/bin/bash
set +e
# ZIVPN Menu - COLOR UI (MULTI USER)
# READY FOR SELLING | NO AUTO BLOCK

CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"
DOMAIN_FILE="/etc/zivpn/domain.conf"
TG_CONF="/etc/zivpn/telegram.conf"

mkdir -p /etc/zivpn
touch "$DB"
[ ! -f "$DOMAIN_FILE" ] && echo "-" > "$DOMAIN_FILE"
[ ! -f "$TG_CONF" ] && echo -e "BOT_TOKEN=\nCHAT_ID=" > "$TG_CONF"

source "$TG_CONF"
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
echo -e "${YELLOW}10${NC}) Backup & Restore (Telegram)"
echo -e "${RED} 0${NC}) Exit"
echo -e "${CYAN}══════════════════════════════════════${NC}"
read -rp " Select Menu : " opt
}

# ===== TELEGRAM SETUP =====
set_telegram() {
clear
echo "SET TELEGRAM BACKUP"
echo "-----------------------"
read -rp "Input BOT TOKEN : " BOT
read -rp "Input CHAT ID   : " CID

if [[ -z "$BOT" || -z "$CID" ]]; then
  echo "Bot Token & Chat ID wajib diisi"
  sleep 2
  return
fi

cat > "$TG_CONF" <<EOF
BOT_TOKEN="$BOT"
CHAT_ID="$CID"
EOF

chmod 600 "$TG_CONF"
source "$TG_CONF"

echo "Telegram config saved"
sleep 2
}

backup_zivpn() {
source "$TG_CONF"
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "Telegram belum dikonfigurasi"
  sleep 2
  return
fi

DATE=$(date +"%Y-%m-%d_%H-%M")
TMP="/root/zivpn-backup-$DATE.tar.gz"

tar -czf "$TMP" \
  /etc/zivpn \
  "$TG_CONF" 2>/dev/null

curl -s -F document=@"$TMP" \
"https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=$CHAT_ID&caption=ZIVPN Backup $DATE"

rm -f "$TMP"
echo "Backup berhasil dikirim ke Telegram"
sleep 2
}

restore_zivpn() {
read -rp "Paste Telegram FILE URL : " URL
[ -z "$URL" ] && return

TMP="/root/zivpn-restore.tar.gz"
wget -O "$TMP" "$URL" || { echo "Download gagal"; sleep 2; return; }

tar -xzf "$TMP" -C /
rm -f "$TMP"

[ -f "$TG_CONF" ] && source "$TG_CONF"
systemctl restart zivpn

echo "Restore berhasil"
sleep 2
}

while true; do
menu
case $opt in
1) create_account ;;
2) list_accounts; read -p "Press Enter..." ;;
3) delete_account ;;
4) echo "Renew gunakan menu lama"; sleep 2 ;;
5) systemctl restart zivpn ;;
6) delete_all_expired ;;
7) ip_monitor ;;
8) change_domain ;;
9)
curl -fsSL https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh -o /usr/bin/zivpn-menu
chmod +x /usr/bin/zivpn-menu
exec bash /usr/bin/zivpn-menu
;;
10)
clear
echo "BACKUP & RESTORE TELEGRAM"
echo "---------------------------"
echo "1) Set Bot Token & Chat ID"
echo "2) Backup ke Telegram"
echo "3) Restore dari Telegram"
read -rp "Pilih : " BR
case $BR in
  1) set_telegram ;;
  2) backup_zivpn ;;
  3) restore_zivpn ;;
esac
;;
0) exit ;;
esac
done
