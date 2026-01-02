#!/bin/bash
# ZIVPN UDP Installer (REBOOT SAFE, SSH SAFE, CTRL+C SAFE)
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
echo "$DOMAIN" > /etc/zivpn/domain.conf

cat > /etc/zivpn/config.json << EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["qwerty99"]
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
/usr/bin/zivpn-menu
EOF
chmod +x /usr/bin/menu

echo "[9/10] Auto start menu on SSH login (CTRL+C SAFE)"
cat > /etc/profile.d/zivpn-autostart.sh << 'EOF'
#!/bin/bash
if [[ -n "$SSH_CONNECTION" ]] && [[ -t 0 ]] && [[ -z "$ZIVPN_MENU_LOADED" ]]; then
  export ZIVPN_MENU_LOADED=1
  clear
  /usr/bin/zivpn-menu
fi
EOF
chmod +x /etc/profile.d/zivpn-autostart.sh

cat > /usr/bin/zivpn-expire.sh << 'EOF'
#!/bin/bash

# ===== FIX PATH UNTUK CRON =====
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"

NOW_TS=$(date +%s)

[ ! -f "$DB" ] && exit 0

TMP="/tmp/zivpn-clean.db"
> "$TMP"

while IFS='|' read -r USER PASS EXP LIMIT; do

  # akun harian → expired jam 23:59
  if [[ "$EXP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    EXP="$EXP 23:59"
  fi

  EXP_TS=$(date -d "$EXP" +%s 2>/dev/null)

  # jika gagal parse → simpan (aman)
  if [[ -z "$EXP_TS" ]]; then
    echo "$USER|$PASS|$EXP|$LIMIT" >> "$TMP"
    continue
  fi

  # expired → hapus
  if (( EXP_TS <= NOW_TS )); then
    jq --arg pass "$PASS" '.auth.config -= [$pass]' "$CONFIG" > /tmp/z.json && mv /tmp/z.json "$CONFIG"
  else
    echo "$USER|$PASS|$EXP|$LIMIT" >> "$TMP"
  fi

done < "$DB"

mv "$TMP" "$DB"
systemctl restart zivpn
EOF

# permission
chmod +x /usr/bin/zivpn-expire.sh

# cron tiap 1 menit
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/zivpn-expire.sh >/dev/null 2>&1") | crontab -


timedatectl set-timezone Asia/Jakarta

echo
echo "======================================"
echo " ZIVPN UDP INSTALLED SUCCESSFULLY"
echo " Domain : $DOMAIN"
echo " AUTO DELETE : DATE + TIME"
echo " Trial menit : AMAN"
echo " SSH LOGIN → AUTO MENU"
echo " CTRL + C → BACK TO SHELL"
echo " Manual menu : menu"
echo "======================================"
