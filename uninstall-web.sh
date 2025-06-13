#!/bin/bash

WEB_ROOT="/var/www"

# === Cek root ===
if [[ $EUID -ne 0 ]]; then
  echo "❌ Script harus dijalankan sebagai root!"
  exit 1
fi

while true; do
  clear
  echo "====================================="
  echo "🧹 UNINSTALL WORDPRESS INSTANCE"
  echo "====================================="
  echo "📂 Folder WordPress yang tersedia:"
  FOLDERS=$(ls -1 "$WEB_ROOT")
  PS3="Select Number (0 untuk keluar): "
  select WP_NAME in $FOLDERS; do
    if [[ -n "$WP_NAME" ]]; then
      break
    elif [[ "$REPLY" == "0" ]]; then
      echo "👋 Keluar."
      exit 0
    else
      echo "❌ Pilihan tidak valid."
    fi
  done

  WP_DIR="$WEB_ROOT/$WP_NAME"
  NGINX_CONF="/etc/nginx/sites-available/wp_$WP_NAME"
  NGINX_LINK="/etc/nginx/sites-enabled/wp_$WP_NAME"
  WPCONFIG="$WP_DIR/wp-config.php"

  echo ""
  echo "Akan menghapus direktori: $WP_DIR"
  echo "Akan menghapus konfigurasi nginx: $NGINX_CONF"
  read -rp "Yakin ingin melanjutkan? (y/n): " CONFIRM
  [[ "$CONFIRM" != "y" ]] && echo "❌ Dibatalkan." && continue

  # Coba ambil nama DB & user dari wp-config.php
  if [ -f "$WPCONFIG" ]; then
      DB_NAME=$(grep DB_NAME "$WPCONFIG" | cut -d \' -f 4)
      DB_USER=$(grep DB_USER "$WPCONFIG" | cut -d \' -f 4)

      echo "🗃️ Database terdeteksi dari wp-config.php:"
      echo "   DB_NAME = $DB_NAME"
      echo "   DB_USER = $DB_USER"

      read -rp "Ingin hapus database dan user MySQL ini? (y/n): " DELETE_DB
      if [[ "$DELETE_DB" == "y" ]]; then
          mysql -uroot -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;"
          mysql -uroot -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';"
          echo "✅ Database dan user MySQL dihapus"
      fi
  else
      echo "⚠️ File wp-config.php tidak ditemukan, database tidak bisa dideteksi otomatis."
  fi

  # Hapus direktori WordPress
  if [ -d "$WP_DIR" ]; then
      rm -rf "$WP_DIR"
      echo "✅ Direktori $WP_DIR dihapus"
  else
      echo "⚠️ Direktori $WP_DIR tidak ditemukan"
  fi

  # Hapus konfigurasi nginx
  if [ -f "$NGINX_CONF" ]; then
      rm -f "$NGINX_CONF"
      echo "✅ File konfigurasi $NGINX_CONF dihapus"
  fi

  if [ -L "$NGINX_LINK" ]; then
      rm -f "$NGINX_LINK"
      echo "✅ Symlink $NGINX_LINK dihapus"
  fi

  echo "🔄 Reload nginx..."
  systemctl reload nginx

  # Tanyakan apakah ingin uninstall seluruh stack LEMP
  read -rp "Apakah ingin menghapus semua paket LEMP dari sistem (nginx, mariadb, php)? (y/n): " FULL_REMOVE
  if [[ "$FULL_REMOVE" == "y" ]]; then
      apt purge nginx mariadb-server php php-mysql php-fpm -y
      apt autoremove --purge -y
      echo "🧹 Semua paket LEMP telah dihapus"
  fi

  # Bersihkan sisa config nginx
  echo "🧹 Membersihkan konfigurasi Nginx yang tidak punya folder WordPress..."
  for conf in /etc/nginx/sites-available/wp_*; do
    [ -e "$conf" ] || continue
    PORT=$(basename "$conf" | cut -d'_' -f2)
    ROOT=$(grep "root " "$conf" | head -n1 | awk '{print $2}' | sed 's/;//')
    if [[ ! -d "$ROOT" ]]; then
      echo "🗑️ Menghapus config nginx untuk port $PORT karena folder $ROOT tidak ada..."
      rm -f "$conf"
      rm -f "/etc/nginx/sites-enabled/wp_$PORT"
    fi
  done

  systemctl reload nginx
  echo "✅ Pembersihan config nginx selesai."
  echo "✅ Uninstall selesai untuk instance: $WP_NAME"
  echo ""
  read -rp "Tekan Enter untuk kembali ke menu..."
done
