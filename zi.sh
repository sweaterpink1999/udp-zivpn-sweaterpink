#!/bin/bash
# ZIVPN UDP Installer (REBOOT SAFE & SSH SAFE)

echo "======================================"
echo "        ZIVPN UDP INSTALLER"
echo "======================================"

echo "[1/8] Update system & dependencies"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget jq iptables iptables-persistent dos2unix

echo "[2/8] Detect architecture"
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
  BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "[3/8] Download ZIVPN binary"
wget -O /usr/local/bin/zivpn "$BIN_URL"
chmod +x /usr/local/bin/zivpn

echo "[4/8] Setup config & certificate"
mkdir -p /etc/zivpn

cat > /etc/zivpn/config.json << EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["zi"]
  }
}
EOF

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/C=ID/ST=VPN/L=ZIVPN/O=ZIVPN/OU=ZIVPN/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt 2>/dev/null

echo "[5/8] Enable IP Forward (PERMANENT)"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-zivpn.conf
sysctl -p /etc/sysctl.d/99-zivpn.conf

echo "[6/8] Install systemd service"
cat > /etc/systemd/system/zivpn.service << EOF
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

echo "[7/8] Setup firewall & NAT (SSH SAFE)"
IFACE=$(ip -4 route | awk '/default/ {print $5}' | head -1)

iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
iptables -A FORWARD -p udp --dport 5667 -j ACCEPT
iptables -A FORWARD -p udp --sport 5667 -j ACCEPT

iptables -A INPUT -p udp --dport 5667 -m connlimit --connlimit-above 3 -j DROP

netfilter-persistent save

echo "[8/8] Install menu"
wget -O /usr/bin/zivpn-menu https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh
dos2unix /usr/bin/zivpn-menu
chmod +x /usr/bin/zivpn-menu

cat > /usr/bin/menu << 'EOF'
#!/bin/bash
exec bash /usr/bin/zivpn-menu
EOF
chmod +x /usr/bin/menu

echo "[9/9] Install auto delete expired user (CRON)"

cat > /usr/bin/zivpn-expire.sh << 'EOF'
#!/bin/bash
CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"
TODAY=$(date +"%Y-%m-%d")

[ ! -f "$DB" ] && exit 0

while IFS='|' read -r USER PASS EXP; do
  if [[ "$EXP" < "$TODAY" ]]; then
    sed -i "\|$USER|$PASS|$EXP|d" "$DB"
    jq --arg pass "$PASS" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
  fi
done < "$DB"

systemctl restart zivpn
EOF

chmod +x /usr/bin/zivpn-expire.sh

(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/zivpn-expire.sh >/dev/null 2>&1") | crontab -

echo "======================================"
echo " ZIVPN UDP INSTALLED SUCCESSFULLY"
echo " SSH SAFE | REBOOT SAFE"
echo " Type command : menu"
echo "======================================"
