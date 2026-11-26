# Chromium Docker Installer

Script otomasi instalasi browser Chromium berbasis desktop Linux di dalam container Docker pada Virtual Private Server (VPS). Browser dapat diakses langsung melalui peramban web modern tanpa perlu memasang desktop environment (GUI) tambahan pada sistem VPS. 

Installer ini dirancang melalui script `install_chromium.sh` ("Chromium Docker Installer - Erick Crypto") untuk menyederhanakan pemasangan dependensi, manajemen swap, konfigurasi Docker Compose, pengaturan firewall, dan pengamanan akses menggunakan kredensial acak.

---

## Daftar Isi

- [Fitur](#fitur)
- [Persyaratan Sistem](#persyaratan-sistem)
- [Langkah Instalasi](#langkah-instalasi)
- [Akses Setelah Instalasi](#akses-setelah-instalasi)
- [Konfigurasi](#konfigurasi)
- [Perintah Berguna](#perintah-berguna)
- [Troubleshooting](#troubleshooting)
- [Keamanan](#keamanan)
- [Lisensi](#lisensi)

---

## Fitur

- **Otomasi Penuh**: Script menangani pembaruan paket sistem, pemasangan Docker CE, Docker Compose, dan dependensi pendukung secara otomatis.
- **Optimasi Resource Ringan**: Dikonfigurasi dengan mode "Chromium Standard + Optimasi RAM" (alokasi memori `mem_limit: 800m` dan `memswap_limit: 1800m`, serta `shm_size: 512mb`).
- **Swap Otomatis**: Menyediakan alokasi swap file sebesar 2GB (`/swapfile`) secara otomatis jika sistem VPS belum memiliki ruang swap aktif.
- **Otentikasi Aman**: Pembuatan pasangan username dan password acak berbasis `openssl` unik pada setiap kali script dijalankan.
- **Akses Fleksibel**: Menyediakan jalur koneksi web client melalui protokol HTTP (port 3010) maupun HTTPS (port 3011).
- **Pengaturan Tampilan Khusus**: Menjalankan rendering visual web client melalui Selkies encoder (resolusi default 1024x600, 24 FPS) yang hemat bandwidth.
- **Konfigurasi Flag Browser**: Menjalankan flag Chromium khusus untuk menonaktifkan background networking, translasi otomatis, sinkronisasi, dan proteksi sandbox agar kompatibel di dalam container.
- **Pembersihan Cache**: Menghapus sisa cache build dan layer Docker yang tidak terpakai menggunakan `docker system prune -f` setelah deployment selesai.
- **Dukungan Ekstensi**: Ekstensi browser dapat dipasang langsung secara normal melalui Chrome Web Store.

---

## Persyaratan Sistem

Pastikan VPS Anda memenuhi kriteria berikut sebelum menjalankan installer:

| Komponen | Spesifikasi / Syarat |
|---|---|
| **Sistem Operasi** | Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, atau Ubuntu 24.04 LTS |
| **Hak Akses** | Wajib sebagai user `root` (script akan menolak jika bukan root) |
| **Swap** | Diperlukan swap (script otomatis membuat swap 2GB jika belum ada) |
| **Port VPS** | Port TCP `3010` (HTTP) dan `3011` (HTTPS) harus terbuka di firewall |

---

## Langkah Instalasi

Ikuti langkah-langkah di bawah ini pada terminal VPS Anda:

1. Masuk ke server VPS Anda melalui SSH menggunakan akun `root`:
   ```bash
   ssh root@ip-vps-anda
   ```

2. Unduh atau siapkan file script `install_chromium.sh` ke direktori server.

3. Jalankan script installer dengan perintah:
   ```bash
   sudo bash install_chromium.sh
   ```

### Alur Eksekusi Script

1. Jalankan `apt-get update`, lalu instal `curl`, `wget`, `openssl`, dan `ufw`.
2. Jika belum ada swap, buat swap 2GB di `/swapfile`.
3. Instal Docker CE dari repo resmi Docker, atau lewati jika Docker sudah terinstal.
4. Instal Docker Compose melalui symlink plugin atau standalone dari GitHub Releases.
5. Jika folder `~/chromium` sudah ada, hentikan container lama dengan `docker-compose down`.
6. Buat username acak dengan `openssl rand -hex 4` dan password acak dengan `openssl rand -hex 12`.
7. Deteksi timezone sistem; gunakan `Asia/Jakarta` sebagai default.
8. Buat `~/chromium/docker-compose.yaml` dengan konfigurasi berikut:

   ```yaml
   services:
     chromium:
       image: lscr.io/linuxserver/chromium:latest
       container_name: chromium
       security_opt:
         - seccomp:unconfined
       environment:
         - CUSTOM_USER=<dibuat-acak-saat-instalasi>
         - PASSWORD=<dibuat-acak-saat-instalasi>
         - PUID=1000
         - PGID=1000
         - TZ=Asia/Jakarta
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
   ```

9. Buka firewall dengan `ufw allow 3010/tcp` dan `ufw allow 3011/tcp`.
10. Pull image, lalu jalankan `docker-compose up -d`.
11. Simpan kredensial ke `~/chromium_credentials.txt` dan atur izinnya dengan `chmod 600`.
12. Bersihkan cache Docker dengan `docker system prune -f`, lalu tampilkan ringkasan akses.

## Akses Setelah Instalasi

- HTTP: `http://IP-VPS:3010`; HTTPS: `https://IP-VPS:3011`. IP dideteksi otomatis.
- Kredensial tersimpan di `~/chromium_credentials.txt` dengan izin `chmod 600`. Jangan bagikan file itu kepada siapa pun.
- HTTPS menampilkan peringatan sertifikat self-signed. Klik “Advanced”, lalu “Proceed anyway” / “Lanjutkan”.
- Tunggu 30-60 detik setelah akses pertama agar tampilan muncul (software renderer).
- Ekstensi dipasang normal dari Chrome Web Store.

## Konfigurasi

Ubah `~/chromium/docker-compose.yaml`, lalu restart dengan `cd ~/chromium && docker-compose restart`, atau jalankan `down` lalu `up -d`. Pengaturan yang bisa diubah: port (`3010:3000` / `3011:3001`), RAM (`mem_limit 800m`, `memswap_limit 1800m`, `shm_size 512mb`), resolusi (`DISPLAY_WIDTH=1024`, `DISPLAY_HEIGHT=600`), dan timezone (`TZ`).

## Perintah Berguna

- `docker ps` — cek status; `docker logs chromium` — lihat log; `docker restart chromium` — restart container.
- `cd ~/chromium && docker-compose down` — stop; `docker-compose up -d` — start.
- `docker pull lscr.io/linuxserver/chromium:latest` lalu `up -d` — update image.

## Troubleshooting

- Container tidak muncul: tunggu 30-60 detik, lalu cek `docker logs chromium`.
- Port tidak bisa diakses: cek `ufw allow 3010/tcp`, `ufw allow 3011/tcp`, dan firewall provider VPS.
- Peringatan sertifikat HTTPS: normal (self-signed); klik Advanced → Proceed anyway.
- Lupa password: baca `~/chromium_credentials.txt`. Jika file hilang, password tidak bisa diambil — instal ulang.
- Bukan root: script menolak; jalankan dengan `sudo`.
- Docker belum terinstal: script menginstalnya otomatis.

## Keamanan

Kredensial dibuat acak untuk setiap instalasi. File kredensial menggunakan `chmod 600`; jangan commit file tersebut ke repo. Batasi akses port bila perlu.

## Lisensi

Belum ditentukan.
