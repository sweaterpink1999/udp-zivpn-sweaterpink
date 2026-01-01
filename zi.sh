#!/bin/bash
# ZIVPN UDP Installer (REBOOT SAFE & SSH SAFE)

set -e

echo "======================================"
echo "        ZIVPN UDP INSTALLER"
echo "======================================"

echo "[1/8] Update system"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget iptables iptables-persistent ufw

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

echo "[7/8] Setup firewall & NAT (SAFE MODE)"
IFACE=$(ip -4 route | awk '/default/ {print $5}' | head -1)

# NAT rules (ZIVPN)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE

# Forward rules
iptables -A FORWARD -p udp --dport 5667 -j ACCEPT
iptables -A FORWARD -p udp --sport 5667 -j ACCEPT

# SAVE IPTABLES ONLY (NO AUTO UFW ENABLE → SSH AMAN)
netfilter-persistent save

echo "[8/8] Install menu"
wget -O /usr/bin/zivpn-menu https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh
chmod +x /usr/bin/zivpn-menu

echo "======================================"
echo " ZIVPN UDP INSTALLED SUCCESSFULLY"
echo " SSH SAFE | REBOOT SAFE"
echo " Menu command : zivpn-menu"
echo "======================================"
