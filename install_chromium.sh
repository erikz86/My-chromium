
#!/bin/bash

# ============================================================
#   Chromium Docker Installer - Erick Crypto
#   OS      : Ubuntu 20.04 / 22.04 / 24.04
#   Akses   : HTTP :3010 & HTTPS :3011
#   Auth    : Username & Password random
#   Mode    : Chromium Standard + Optimasi RAM
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✘]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[i]${NC} $1"; }

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}        Chromium Docker Installer - Erick Crypto            ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# ─── Cek root ───────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "Jalankan script ini sebagai root: sudo bash my_chromium.sh"
fi

# ─── Cek OS ─────────────────────────────────────────────────
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
if [[ "$OS_ID" != "ubuntu" ]]; then
  warn "Script ini dioptimalkan untuk Ubuntu. OS terdeteksi: $OS_ID $OS_VER"
fi
log "OS: $OS_ID $OS_VER"

# ─── Update sistem ───────────────────────────────────────────
info "Update sistem..."
apt-get update -y > /dev/null 2>&1
apt-get install -y curl wget openssl ufw > /dev/null 2>&1
log "Sistem sudah terupdate"

# ─── Tambah Swap jika belum ada ─────────────────────────────
SWAP=$(swapon --show | wc -l)
if [ "$SWAP" -eq 0 ]; then
  info "Menambahkan Swap 2GB..."
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile > /dev/null
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  log "Swap 2GB aktif"
else
  log "Swap sudah aktif, skip"
fi

# ─── Install Docker (support Ubuntu 20, 22, 24) ─────────────
if ! command -v docker &>/dev/null; then
  info "Menginstall Docker..."
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y $pkg > /dev/null 2>&1 || true
  done
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null 2>&1

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg > /dev/null 2>&1
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y > /dev/null 2>&1
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
  systemctl start docker
  systemctl enable docker > /dev/null 2>&1
  log "Docker terinstall"
else
  log "Docker sudah ada, skip"
fi

# ─── Install Docker Compose ─────────────────────────────────
if ! command -v docker-compose &>/dev/null; then
  if docker compose version &>/dev/null 2>&1; then
    ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>/dev/null || \
    ln -sf $(which docker) /usr/local/bin/docker-compose 2>/dev/null || true
    log "Docker Compose (plugin) sudah ada, dibuat symlink"
  else
    info "Menginstall Docker Compose standalone..."
    curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log "Docker Compose terinstall"
  fi
else
  log "Docker Compose sudah ada, skip"
fi

# ─── Hentikan container lama jika ada ───────────────────────
if [ -d "$HOME/chromium" ]; then
  warn "Folder chromium sudah ada, menghapus container lama..."
  cd $HOME/chromium
  docker-compose down > /dev/null 2>&1 || true
  cd $HOME
fi

# ─── Generate kredensial ────────────────────────────────────
CUSTOM_USER=$(openssl rand -hex 4)
PASSWORD=$(openssl rand -hex 12)

# ─── Deteksi timezone ───────────────────────────────────────
TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
[ -z "$TIMEZONE" ] && TIMEZONE="Asia/Jakarta"
log "Timezone: $TIMEZONE"

# ─── Buat folder & docker-compose.yaml ─────────────────────
info "Membuat konfigurasi Chromium..."
mkdir -p $HOME/chromium

cat > $HOME/chromium/docker-compose.yaml <<EOF
---
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=${CUSTOM_USER}
      - PASSWORD=${PASSWORD}
      - PUID=1000
      - PGID=1000
      - TZ=${TIMEZONE}
      - LANG=en_US.UTF-8
      - CHROME_CLI=--disable-dev-shm-usage --disable-gpu-sandbox --no-sandbox --disable-background-networking --disable-default-apps --memory-pressure-off --disable-hang-monitor --disable-prompt-on-repost --disable-sync --disable-translate --metrics-recording-only --safebrowsing-disable-auto-update https://google.com/
      - DISPLAY_WIDTH=1024
      - DISPLAY_HEIGHT=600
      - SELKIES_ENCODER=jpeg
      - SELKIES_VIDEO_BITRATE=2
      - SELKIES_FRAMERATE=24
      - SELKIES_JPEG_QUALITY=60
    volumes:
      - /root/chromium/config:/config
    ports:
      - 3010:3000
      - 3011:3001
    shm_size: "512mb"
    mem_limit: 800m
    memswap_limit: 1800m
    restart: unless-stopped
EOF

log "docker-compose.yaml dibuat"

# ─── Buka firewall ───────────────────────────────────────────
info "Mengatur firewall..."
ufw allow 3010/tcp > /dev/null 2>&1 || true
ufw allow 3011/tcp > /dev/null 2>&1 || true
log "Port 3010 & 3011 dibuka"

# ─── Pull image ─────────────────────────────────────────────
info "Pull image Chromium Standard (mungkin butuh beberapa menit)..."
docker pull lscr.io/linuxserver/chromium:latest
log "Image berhasil di-pull"

# ─── Jalankan container ─────────────────────────────────────
info "Menjalankan container Chromium..."
cd $HOME/chromium
docker-compose up -d
log "Container Chromium berjalan"

# ─── Simpan kredensial ──────────────────────────────────────
IPVPS=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "IP_VPS_KAMU")
CRED_FILE="$HOME/chromium_credentials.txt"

cat > $CRED_FILE <<EOF
============================================================
  CHROMIUM STANDARD + OPTIMASI RAM - INFORMASI AKSES
============================================================
  IP VPS     : ${IPVPS}
  HTTP       : http://${IPVPS}:3010
  HTTPS      : https://${IPVPS}:3011

  Username   : ${CUSTOM_USER}
  Password   : ${PASSWORD}

  Timezone   : ${TIMEZONE}
  Mode       : Chromium Standard + Optimasi RAM
  Install    : $(date '+%Y-%m-%d %H:%M:%S')
============================================================
CATATAN:
- Akses HTTPS akan muncul peringatan sertifikat, klik
  "Advanced" lalu "Proceed anyway" / "Lanjutkan"
- Tunggu 30-60 detik setelah pertama akses agar
  tampilan muncul (software renderer)
- RAM limit: 800MB | Swap: 1800MB
- Ekstensi: Install normal dari Chrome Web Store
============================================================
EOF

chmod 600 $CRED_FILE

# ─── Bersihkan cache Docker ──────────────────────────────────
docker system prune -f > /dev/null 2>&1

# ─── Tampilkan hasil ─────────────────────────────────────────
echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI! INFORMASI AKSES:                 ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e "  ${YELLOW}HTTP  ${NC}: http://${IPVPS}:3010"
echo -e "  ${YELLOW}HTTPS ${NC}: https://${IPVPS}:3011"
echo ""
echo -e "  ${YELLOW}Username${NC}: ${CUSTOM_USER}"
echo -e "  ${YELLOW}Password${NC}: ${PASSWORD}"
echo ""
echo -e "  ${CYAN}Mode    ${NC}: Chromium Standard + Optimasi RAM"
echo -e "  ${CYAN}RAM     ${NC}: Limit 800MB + Swap 1800MB"
echo -e "  ${CYAN}Ekstensi${NC}: Install dari Chrome Web Store (normal)"
echo -e "  ${CYAN}Kredensial tersimpan di:${NC} ~/chromium_credentials.txt"
echo -e "${CYAN}============================================================${NC}"
echo ""
warn "Tunggu 30-60 detik setelah buka browser sebelum tampilan muncul!"
warn "Untuk HTTPS: klik 'Advanced' → 'Proceed anyway' jika ada peringatan"
echo ""
