#!/bin/sh
set -e

# Sistem paketlerini güncelle
opkg update

# Temel dnsmasq paketini tam sürümle değiştir
opkg remove dnsmasq
opkg install dnsmasq-full

# Gerekli kernel modüllerini yükle
opkg install kmod-nft-tproxy kmod-nft-socket

# Passwall public anahtarını indir ve sisteme tanıt
wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add passwall.pub
rm -f passwall.pub

# OpenWrt sürüm ve mimari değişkenlerini al
. /etc/openwrt_release
RELEASE="${DISTRIB_RELEASE%.*}"
ARCH="${DISTRIB_ARCH}"

# Passwall feed'lerini yapılandırmaya ekle
for feed in passwall_packages passwall2; do
    echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-${RELEASE}/${ARCH}/$feed" >> /etc/opkg/customfeeds.conf
done

# Listeleri tekrar güncelle ve hedef paketleri kur
opkg update
opkg install luci-app-passwall2 v2ray-geosite-ir