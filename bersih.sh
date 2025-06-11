#!/bin/bash

# Script: clear.sh
# Tujuan: Membersihkan file sementara, cache, dan sampah yang tidak digunakan
# Jalankan sebagai root untuk hasil maksimal

echo "🔄 Memulai proses pembersihan..."

# 1. Bersihkan cache APT (untuk Debian/Ubuntu/Armbian)
echo "🧹 Membersihkan cache APT..."
apt-mark manual nginx php mariadb-server
apt clean
apt autoclean
apt autoremove -y
apt autoremove --purge
dpkg -l | grep '^rc' | awk '{print $2}' | xargs -r sudo dpkg --purge


# 2. Hapus file temporary sistem
echo "🧹 Menghapus file di /tmp dan /var/tmp..."
rm -rf /tmp/* /var/tmp/*

# 3. Bersihkan cache thumbnail (untuk lingkungan desktop)
echo "🧹 Menghapus cache thumbnail..."
rm -rf ~/.cache/thumbnails/* 2>/dev/null

# 4. Bersihkan cache user
echo "🧹 Menghapus file cache user di ~/.cache..."
rm -rf ~/.cache/*

# 5. Bersihkan log systemd (menyimpan hanya 7 hari)
echo "🧹 Membersihkan log lama..."
journalctl --vacuum-time=7d

# 6. Bersihkan Trash
echo "🧹 Mengosongkan tempat sampah (Trash)..."
TRASH_DIR="$HOME/.local/share/Trash"
if [ -d "$TRASH_DIR/files" ]; then
  rm -rf "$TRASH_DIR/files/"* 2>/dev/null
fi
if [ -d "$TRASH_DIR/info" ]; then
  rm -rf "$TRASH_DIR/info/"* 2>/dev/null
fi

# 7. Bersihkan cache pip (jika pip tersedia)
if command -v pip &>/dev/null; then
  echo "🧹 Menghapus cache pip..."
  rm -rf ~/.cache/pip
fi

# 8. Bersihkan cache npm (jika npm tersedia)
if command -v npm &>/dev/null; then
  echo "🧹 Menghapus cache npm..."
  npm cache clean --force
fi

# 9. Bersihkan log rotate yang lama
echo "🧹 Menghapus log rotate lama..."
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.1" -delete
find /var/log -type f -name "*.old" -delete

# 10. Bersihkan file APT lists lama
echo "🧹 Menghapus file APT lists lama..."
rm -rf /var/lib/apt/lists/*

echo "✅ Pembersihan selesai!"
