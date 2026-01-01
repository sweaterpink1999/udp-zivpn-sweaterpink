#!/bin/bash
# ZIVPN Menu - SAFE & ORI COMPATIBLE

CONFIG="/etc/zivpn/config.json"
PORT_RANGE="6000-19999"

clear
echo "===================================="
echo "        ZIVPN SIMPLE MENU"
echo "===================================="
echo "1. Create Account (Rotate Password)"
echo "2. Show Active Password"
echo "3. Restart ZIVPN"
echo "0. Exit"
echo "===================================="
read -p "Select Menu : " opt

case $opt in

1)
SERVER_IP=$(curl -s ifconfig.me)
read -p "Username (bebas): " USER
read -p "Duration days  : " DAYS

PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
EXP=$(date -d "$DAYS days" +"%Y-%m-%d")

# === ROTATE PASSWORD SAJA (JANGAN REWRITE CONFIG) ===
sed -i -E 's/"config":[[:space:]]*\[[^]]*\]/"config":["'"$PASS"'"]/' "$CONFIG"

systemctl restart zivpn

clear
echo "===================================="
echo "        ZIVPN UDP ACCOUNT"
echo "===================================="
echo "Server IP        : $SERVER_IP"
echo "Port Range       : $PORT_RANGE"
echo "User             : $USER"
echo "Password         : $PASS"
echo "Duration days    : $DAYS"
echo "Connection Limit : Multilogin"
echo "Expiration date  : $EXP"
echo "===================================="
;;

2)
echo "Active password:"
grep -oP '"config":\s*\[\s*"\K[^"]+' "$CONFIG"
;;

3)
systemctl restart zivpn
echo "ZIVPN restarted"
;;

0)
exit
;;

*)
echo "Invalid option"
;;
esac
