#!/bin/sh
set -e

# 1. Sistem paketlerini güncelle ve bağımlılıkları kur
opkg update
opkg remove dnsmasq || true
opkg install dnsmasq-full kmod-nft-tproxy kmod-nft-socket unzip ca-bundle

# 2. Mimariyi çek
. /etc/openwrt_release
ARCH="${DISTRIB_ARCH}"
VERSION="26.5.1-1"

# 3. Geçici çalışma alanı oluştur
mkdir -p /tmp/passwall
cd /tmp/passwall



URL="https://github.com/Openwrt-Passwall/openwrt-passwall2/releases/download/26.5.1-1/passwall_packages_ipk_x86_64.zip"


# 4. Paketleri indir ve aç
wget -O passwall.zip "$URL"
unzip -q passwall.zip

# 5. Tüm ipk dosyalarını kur
opkg install *.ipk

# 6. Temizlik (Güvenlik ve hafıza için zorunlu)
cd /
rm -rf /tmp/passwall