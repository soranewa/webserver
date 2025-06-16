#!/bin/bash

# Script: bersih.sh
# Tujuan: Membersihkan sistem tanpa mengganggu stack LEMP
# Jalankan sebagai root untuk hasil optimal

GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${CYAN}🔄 Memulai proses pembersihan sistem...${RESET}"

# 1. Bersihkan cache APT
echo -e "${YELLOW}🧹 Membersihkan cache APT...${RESET}"
apt-mark manual nginx php mariadb-server
apt clean
apt autoclean
apt autoremove -y
apt autoremove --purge
dpkg -l | grep '^rc' | awk '{print $2}' | xargs -r dpkg --purge

# 2. Hapus file temporary sistem
echo -e "${YELLOW}🧹 Menghapus file di /tmp dan /var/tmp...${RESET}"
rm -rf /tmp/* /var/tmp/*

# 3. Bersihkan cache thumbnail (jika desktop)
echo -e "${YELLOW}🧹 Menghapus cache thumbnail...${RESET}"
rm -rf ~/.cache/thumbnails/* 2>/dev/null

# 4. Bersihkan cache user
echo -e "${YELLOW}🧹 Menghapus file cache user...${RESET}"
rm -rf ~/.cache/*

# 5. Bersihkan log systemd
echo -e "${YELLOW}🧹 Membersihkan log lama (7 hari ke atas)...${RESET}"
journalctl --vacuum-time=7d

# 6. Kosongkan tempat sampah
echo -e "${YELLOW}🧹 Mengosongkan tempat sampah (Trash)...${RESET}"
TRASH_DIR="$HOME/.local/share/Trash"
[ -d "$TRASH_DIR/files" ] && rm -rf "$TRASH_DIR/files/"* 2>/dev/null
[ -d "$TRASH_DIR/info" ] && rm -rf "$TRASH_DIR/info/"* 2>/dev/null

# 7. Bersihkan cache pip
if command -v pip &>/dev/null; then
  echo -e "${YELLOW}🧹 Menghapus cache pip...${RESET}"
  rm -rf ~/.cache/pip
fi

# 8. Bersihkan cache npm
if command -v npm &>/dev/null; then
  echo -e "${YELLOW}🧹 Menghapus cache npm...${RESET}"
  npm cache clean --force
fi

# 9. Hapus log rotate lama
echo -e "${YELLOW}🧹 Menghapus log rotate lama...${RESET}"
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.1" -delete
find /var/log -type f -name "*.old" -delete

# 10. Hapus file APT list lama
echo -e "${YELLOW}🧹 Menghapus file APT lists lama...${RESET}"
rm -rf /var/lib/apt/lists/*

# 11. Tutup aplikasi monitoring berat
echo -e "${YELLOW}🧠 Menutup aplikasi berat (htop, btop, glances)...${RESET}"
for p in btop htop top gnome-system-monitor xrestop glances; do
    pkill -f "$p" 2>/dev/null
done

# 12. Bersihkan cache RAM (tanpa ganggu service)
echo -e "${YELLOW}🧠 Melepaskan cache RAM (drop_caches)...${RESET}"
sync
echo 3 > /proc/sys/vm/drop_caches

# 13. Tampilkan sisa RAM setelah dibersihkan
echo -e "${CYAN}📊 Status RAM setelah dibersihkan:${RESET}"
free -h

# 14. Bersihkan file sementara dari curl <(bash)
echo -e "${YELLOW}🧼 Menghapus file sementara dari curl (<(bash))...${RESET}"
find /tmp -type f -name 'sh-*' -delete 2>/dev/null

echo -e "${GREEN}✅ Pembersihan selesai dengan sukses! Tetap semangat dan sehat selalu! 🚀${RESET}"
