#!/bin/bash
# ZIVPN UDP Module Installer (FULL)
# Auto Install + Menu + User + Limit IP + Limit GB

clear
echo "======================================="
echo "     ZIVPN UDP FULL INSTALLER"
echo "======================================="

echo "[1/7] Update Server"
apt-get update -y && apt-get upgrade -y

echo "[2/7] Install Dependency"
apt-get install -y wget curl openssl vnstat iptables ufw

systemctl stop zivpn.service 2>/dev/null

echo "[3/7] Download ZIVPN Binary"
wget -q https://github.com/sweaterpink1999/udp-zivpn-sweaterpink/releases/download/udp-zivpn-sweaterpink_1.4.9/udp-zivpn-sweaterpink-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn
wget -q https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/config.json -O /etc/zivpn/config.json

echo "[4/7] Generate SSL Certificate"
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/C=ID/ST=VPN/L=ZIVPN/O=ZIVPN/OU=ZIVPN/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt 2>/dev/null

sysctl -w net.core.rmem_max=16777216 >/dev/null
sysctl -w net.core.wmem_max=16777216 >/dev/null

echo "[5/7] Create Systemd Service"
cat > /etc/systemd/system/zivpn.service << EOF
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[6/7] Setup Firewall"
IFACE=$(ip -4 route ls | grep default | awk '{print $5}' | head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

echo "[7/7] Install Menu & User System"

# ===== MENU =====
cat > /usr/bin/zivpn-menu << 'EOF'
#!/bin/bash
clear
echo "=========== ZIVPN MENU ==========="
echo "1. Create User"
echo "2. Delete User"
echo "3. List User"
echo "4. Extend User"
echo "5. Restart ZIVPN"
echo "6. Check Traffic (vnstat)"
echo "0. Exit"
echo "================================="
read -p "Select : " menu

case $menu in
1)
read -p "Username : " u
read -p "Password : " p
read -p "Expired (days): " d
exp=$(date -d "$d days" +"%Y-%m-%d")
useradd -M -s /usr/sbin/nologin -e $exp $u
echo "$u:$p" | chpasswd
echo "User $u created, expire $exp"
;;
2)
read -p "Username : " u
userdel $u
echo "User deleted"
;;
3)
awk -F: '$3>=1000 {print $1}' /etc/passwd
;;
4)
read -p "Username : " u
read -p "Add days : " d
chage -E $(date -d "+$d days" +"%Y-%m-%d") $u
echo "Extended"
;;
5)
systemctl restart zivpn
echo "ZIVPN restarted"
;;
6)
vnstat
;;
0)
exit
;;
esac
EOF
chmod +x /usr/bin/zivpn-menu

# ===== AUTO DELETE EXPIRED =====
cat > /usr/bin/zivpn-expired << 'EOF'
#!/bin/bash
today=$(date +"%Y-%m-%d")
for u in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do
exp=$(chage -l $u | awk -F": " '/Account expires/{print $2}')
[ "$exp" != "never" ] && [ "$(date -d "$exp" +%Y-%m-%d)" \< "$today" ] && userdel $u
done
EOF
chmod +x /usr/bin/zivpn-expired
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/zivpn-expired") | crontab -

systemctl enable vnstat
systemctl start vnstat

echo "======================================="
echo " ZIVPN UDP FULLY INSTALLED"
echo " Command Menu : zivpn-menu"
echo "======================================="
