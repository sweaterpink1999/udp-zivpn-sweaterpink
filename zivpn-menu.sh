#!/bin/bash
# ZIVPN Menu - PREMIUM UI (SAFE & ORI)

CONFIG="/etc/zivpn/config.json"
PORT_RANGE="6000-19999"

# ===== SYSTEM INFO =====
OS=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2)
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
printf " OS      : %s\n" "$OS"
printf " IP      : %s\n" "$IP"
printf " Uptime  : %s\n" "$UPTIME"
printf " CPU     : %s Cores\n" "$CPU"
printf " RAM     : %s / %s MB\n" "$RAM_USED" "$RAM_TOTAL"
printf " Disk    : %s / %s\n" "$DISK_USED" "$DISK_TOTAL"
printf " ZIVPN   : %s\n" "$ZIVPN_STATUS"
echo "--------------------------------------"
echo " 1) Create Account"
echo " 2) Show Active Password"
echo " 3) Restart ZIVPN"
echo " 0) Exit"
echo "--------------------------------------"
read -p " Select Menu : " opt

case $opt in

1)
read -p " Username (bebas) : " USER
read -p " Duration (days)  : " DAYS

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

# ROTATE PASSWORD (SAFE)
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
echo " Duration days    : $DAYS"
echo " Connection Limit : Multilogin"
echo " Expiration date  : $EXP"
echo "===================================="
read -p "Press Enter to return menu..."
exec "$0"
;;

2)
clear
echo "Active password:"
grep -oP '"config":\s*\[\s*"\K[^"]+' "$CONFIG"
echo
read -p "Press Enter to return menu..."
exec "$0"
;;

3)
systemctl restart zivpn
echo "ZIVPN restarted"
sleep 2
exec "$0"
;;

0)
clear
exit
;;

*)
echo "Invalid option"
sleep 1
exec "$0"
;;
esac
