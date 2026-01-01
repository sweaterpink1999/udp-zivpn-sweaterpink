#!/bin/bash
# ZIVPN UDP Installer (REBOOT SAFE & SSH SAFE)
set -e

echo "======================================"
echo "        ZIVPN UDP INSTALLER"
echo "======================================"
echo

# ===== INPUT DOMAIN =====
read -rp "Input Domain (contoh: udp.domainkamu.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "Domain tidak boleh kosong!"
  exit 1
fi

echo
echo "[1/10] Update system & dependencies"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget jq iptables iptables-persistent dos2unix

echo "[2/10] Detect architecture"
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
  BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "[3/10] Download ZIVPN binary"
wget -O /usr/local/bin/zivpn "$BIN_URL"
chmod +x /usr/local/bin/zivpn

echo "[4/10] Setup config, domain & certificate"
mkdir -p /etc/zivpn

# simpan domain
echo "$DOMAIN" > /etc/zivpn/domain.conf

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
-subj "/C=ID/ST=VPN/L=ZIVPN/O=ZIVPN/OU=ZIVPN/CN=$DOMAIN" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt 2>/dev/null

echo "[5/10] Enable IP Forward (PERMANENT)"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-zivpn.conf
sysctl -p /etc/sysctl.d/99-zivpn.conf

echo "[6/10] Install systemd service"
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
systemctl restart zivpn

echo "[7/10] Setup firewall & NAT (SSH SAFE)"
IFACE=$(ip -4 route | awk '/default/ {print $5}' | head -1)

iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
iptables -A FORWARD -p udp --dport 5667 -j ACCEPT
iptables -A FORWARD -p udp --sport 5667 -j ACCEPT

netfilter-persistent save

echo "[8/10] Install menu"
wget -O /usr/bin/zivpn-menu https://raw.githubusercontent.com/sweaterpink1999/udp-zivpn-sweaterpink/main/zivpn-menu.sh
dos2unix /usr/bin/zivpn-menu
chmod +x /usr/bin/zivpn-menu

cat > /usr/bin/menu << 'EOF'
#!/bin/bash
exec /usr/bin/zivpn-menu
EOF
chmod +x /usr/bin/menu

echo "[9/10] Auto start menu on SSH login"
cat > /etc/profile.d/zivpn-autostart.sh << 'EOF'
#!/bin/bash
if [[ -n "$SSH_CONNECTION" ]] && [[ -t 0 ]] && [[ -z "$ZIVPN_MENU_LOADED" ]]; then
  export ZIVPN_MENU_LOADED=1
  clear
  exec /usr/bin/zivpn-menu
fi
EOF
chmod +x /etc/profile.d/zivpn-autostart.sh

echo "[10/10] Install auto delete expired user (CRON)"
cat > /usr/bin/zivpn-expire.sh << 'EOF'
#!/bin/bash
CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"
TODAY=$(date +"%Y-%m-%d")

[ ! -f "$DB" ] && exit 0

while IFS='|' read -r USER PASS EXP LIMIT; do
  if [[ "$EXP" < "$TODAY" ]]; then
    sed -i "\|$USER|$PASS|$EXP|$LIMIT|d" "$DB"
    jq --arg pass "$PASS" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
  fi
done < "$DB"

systemctl restart zivpn
EOF

chmod +x /usr/bin/zivpn-expire.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/zivpn-expire.sh >/dev/null 2>&1") | crontab -

echo
echo "======================================"
echo " ZIVPN UDP INSTALLED SUCCESSFULLY"
echo " Domain : $DOMAIN"
echo " SSH SAFE | REBOOT SAFE"
echo " Login SSH → AUTO MENU"
echo "======================================"
