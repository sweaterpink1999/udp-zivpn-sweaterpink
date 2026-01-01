#!/bin/bash
# ZIVPN UDP Module Installer (FINAL & STABLE)
# Based on original ZIVPN method (safe)

set -e

echo "======================================"
echo "        ZIVPN UDP INSTALLER"
echo "======================================"

echo "[1/7] Update system"
apt-get update -y && apt-get upgrade -y

echo "[2/7] Detect architecture"
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
  BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "[3/7] Download ZIVPN binary"
wget -O /usr/local/bin/zivpn "$BIN_URL"
chmod +x /usr/local/bin/zivpn

echo "[4/7] Setup config & certificate"
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

sysctl -w net.core.rmem_max=16777216 >/dev/null
sysctl -w net.core.wmem_max=16777216 >/dev/null

echo "[5/7] Install systemd service"
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

echo "[6/7] Setup firewall"
IFACE=$(ip -4 route | awk '/default/ {print $5}' | head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp

systemctl daemon-reload
systemctl enable zivpn
systemctl restart zivpn

echo "[7/7] Install menu"
wget -O /usr/bin/zivpn-menu https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh
chmod +x /usr/bin/zivpn-menu

echo "======================================"
echo " ZIVPN UDP INSTALLED SUCCESSFULLY"
echo " Menu command : zivpn-menu"
echo "======================================"
