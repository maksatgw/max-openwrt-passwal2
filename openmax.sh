#!/bin/sh

set -e

echo "[1/7] Paket listesi güncelleniyor..."
opkg update

echo "[2/7] Temel araçlar kuruluyor..."
opkg install curl wget ca-bundle ca-certificates

echo "[3/7] Passwall2 repo ekleniyor..."

grep -q passwall2 /etc/opkg/customfeeds.conf || cat >> /etc/opkg/customfeeds.conf << 'EOF'
src/gz passwall2 https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-23.05/x86_64/passwall2
EOF

opkg update

echo "[4/7] Ana paketler kuruluyor..."
opkg install luci-app-passwall2

echo "[5/7] Xray ve gerekli bileşenler kuruluyor..."
opkg install xray-core xray-plugin v2ray-geoip v2ray-geosite

echo "[6/7] Network bağımlılıkları kuruluyor..."
opkg install dnsmasq-full ipset ip-full

echo "[7/7] TProxy modülleri kuruluyor..."
opkg install kmod-tun kmod-inet-diag kmod-tproxy iptables-mod-tproxy iptables-mod-extra

echo "[+] Servisler yeniden başlatılıyor..."
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo "[✓] Kurulum tamamlandı."
echo ""
echo "Şimdi LuCI üzerinden node ekle:"
echo "Services -> Passwall2"
echo ""
echo "Kontrol için:"
echo "ps | grep xray"