#!/bin/sh
# ============================================================
#  OpenWrt - Passwall2 Temiz Kurulum Scripti
#  Kaynak yöntem: peditx/EZpasswall + xiaorouji feed
#  Özelleştirme yok: tema, hostname, timezone değiştirilmez.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[*] $1${NC}"; }
ok()   { echo -e "${GREEN}[✓] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
err()  { echo -e "${RED}[✗] $1${NC}"; exit 1; }

# ------------------------------------------------------------
# 0. Root kontrolü
# ------------------------------------------------------------
[ "$(id -u)" -ne 0 ] && err "Bu script root olarak çalıştırılmalı."

# ------------------------------------------------------------
# 1. Mimari ve OpenWrt sürümünü tespit et
# ------------------------------------------------------------
log "Sistem bilgisi alınıyor..."

. /etc/openwrt_release

ARCH=$(opkg print-architecture | awk 'NR==2{print $2}')
OPENWRT_VER="$DISTRIB_RELEASE"   # örn: 23.05.3 veya SNAPSHOT

echo "  Model   : $(cat /tmp/sysinfo/model 2>/dev/null || echo 'bilinmiyor')"
echo "  Sürüm   : $OPENWRT_VER"
echo "  Mimari  : $ARCH"
echo ""

# ------------------------------------------------------------
# 2. GitHub erişim sorunu varsa /etc/hosts ile çöz
#    (ağ sorunun yoksa bu bloğu atlayabilirsin)
# ------------------------------------------------------------
fix_github_hosts() {
    warn "GitHub erişim sorunu tespit edildi, /etc/hosts düzenleniyor..."
    # Çalışan IP'yi dene (4 seçenekten biri genelde işe yarar)
    for ip in 185.199.108.133 185.199.109.133 185.199.110.133 185.199.111.133; do
        if curl -s --connect-timeout 5 "https://raw.githubusercontent.com" -o /dev/null 2>/dev/null; then
            ok "GitHub erişimi tamam."
            return
        fi
        # Bu IP'yi dene
        sed -i '/raw.githubusercontent.com/d' /etc/hosts
        echo "$ip raw.githubusercontent.com" >> /etc/hosts
        log "Deneniyor: $ip ..."
        sleep 1
    done
    warn "GitHub erişimi hâlâ sorunlu olabilir, devam ediyorum..."
}

# GitHub'a erişimi kontrol et
if ! curl -s --connect-timeout 8 "https://raw.githubusercontent.com" -o /dev/null 2>/dev/null; then
    fix_github_hosts
fi

# ------------------------------------------------------------
# 3. Temel bağımlılıkları kur
# ------------------------------------------------------------
log "Temel paketler güncelleniyor ve kuruluyor..."

opkg update || warn "opkg update başarısız, devam ediliyor..."

opkg install curl wget-ssl ca-bundle ca-certificates \
    luci-compat luci-lib-ipkg \
    || warn "Bazı temel paketler kurulamadı."

# ------------------------------------------------------------
# 4. Passwall2 feed'ini ekle (xiaorouji resmi)
# ------------------------------------------------------------
log "Passwall2 opkg feed ekleniyor..."

FEED_CONF="/etc/opkg/customfeeds.conf"

# Mevcut passwall feed'lerini temizle (tekrar eklememek için)
sed -i '/passwall/d' "$FEED_CONF" 2>/dev/null

# OpenWrt sürümüne göre doğru feed'i seç
#
# snapshot / 23.05 / 22.03 için xiaorouji'nin genel feed'i:
FEED_BASE="https://github.com/xiaorouji/openwrt-passwall-packages/releases/download/latest"

# Paket feed'leri (luci ayrı, core paketler ayrı)
cat >> "$FEED_CONF" << EOF
src/gz passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages/releases/download/latest/passwall_packages_${ARCH}.zip
EOF

# Alternatif: SourceForge mirror (GitHub bloklu ağlar için yorum satırını aç)
# echo "src/gz passwall_packages https://master.dl.sourceforge.net/project/openwrt-passwall/releases/passwall_packages_${ARCH}.zip" >> "$FEED_CONF"

log "Feed eklendi: passwall_packages_${ARCH}"

# ------------------------------------------------------------
# 5. GPG anahtarını ekle (imza doğrulaması için)
# ------------------------------------------------------------
log "GPG anahtarı indiriliyor..."

wget -qO /tmp/passwall.pub \
    https://github.com/xiaorouji/openwrt-passwall-packages/raw/main/public.key \
    && opkg-key add /tmp/passwall.pub \
    && ok "GPG anahtarı eklendi." \
    || warn "GPG anahtarı eklenemedi, imzasız kurulum deneniyor..."

# ------------------------------------------------------------
# 6. opkg güncelle ve passwall2 kur
# ------------------------------------------------------------
log "Paket listesi güncelleniyor..."
opkg update

log "luci-app-passwall2 kuruluyor..."
opkg install luci-app-passwall2

if [ $? -ne 0 ]; then
    warn "Direkt kurulum başarısız. Bağımlılıkları tek tek deniyorum..."

    # Gerekli bağımlılıkları manuel kur
    for pkg in \
        kmod-nft-tproxy \
        kmod-nf-tproxy \
        ip-full \
        dnsmasq-full \
        xray-core \
        v2ray-geoip \
        v2ray-geosite \
        luci-app-passwall2; do

        log "Kuruluyor: $pkg ..."
        opkg install "$pkg" || warn "$pkg kurulamadı, atlanıyor."
    done
fi

# ------------------------------------------------------------
# 7. dnsmasq çakışmasını çöz (önemli!)
#    dnsmasq-full ile dnsmasq aynı anda olamaz
# ------------------------------------------------------------
if opkg list-installed | grep -q "^dnsmasq "; then
    log "dnsmasq → dnsmasq-full ile değiştiriliyor..."
    opkg remove dnsmasq
    opkg install dnsmasq-full
fi

# ------------------------------------------------------------
# 8. Servis yeniden başlat
# ------------------------------------------------------------
log "Servisler yeniden başlatılıyor..."
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

# ------------------------------------------------------------
# 9. Sonuç
# ------------------------------------------------------------
echo ""
if opkg list-installed | grep -q "luci-app-passwall2"; then
    ok "=============================="
    ok " Passwall2 başarıyla kuruldu!"
    ok "=============================="
    echo ""
    echo "  LuCI → Hizmetler → Passwall2 menüsünden erişebilirsin."
    echo "  Değişikliklerin tam olarak görünmesi için router'ı yeniden başlatmanı öneririm:"
    echo ""
    echo "    reboot"
else
    err "Passwall2 kurulumu doğrulanamadı. Loglara bak: opkg install luci-app-passwall2"
fi