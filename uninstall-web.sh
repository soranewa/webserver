#!/bin/bash

WEB_ROOT="/var/www"

# === Cek root ===
if [[ $EUID -ne 0 ]]; then
  echo "❌ Script harus dijalankan sebagai root!"
  exit 1
fi

while true; do
  clear
  echo "========================================="
  echo "🗑️ UNINSTALL MENU"
  echo "========================================="
  echo "1. Uninstall WordPress Instance"
  echo "2. Uninstall Seluruh LEMP Stack"
  echo "0. Keluar"
  echo "========================================="
  read -rp "Pilih opsi (0-2): " MENU

  case $MENU in
    1)
      echo ""
      echo "📂 List Folder WordPress di $WEB_ROOT:"
      FOLDERS=$(ls -1 "$WEB_ROOT")
      PS3="Select Number (0 untuk batal): "
      select WP_NAME in $FOLDERS; do
        if [[ -n "$WP_NAME" ]]; then
          break
        elif [[ "$REPLY" == "0" ]]; then
          echo "❌ Dibatalkan."
          continue 2
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

      if [ -f "$WPCONFIG" ]; then
          DB_NAME=$(grep DB_NAME "$WPCONFIG" | cut -d '"' -f 2 | cut -d "'" -f 2)
          DB_USER=$(grep DB_USER "$WPCONFIG" | cut -d '"' -f 2 | cut -d "'" -f 2)

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

      if [ -d "$WP_DIR" ]; then
          rm -rf "$WP_DIR"
          echo "✅ Direktori $WP_DIR dihapus"
      else
          echo "⚠️ Direktori $WP_DIR tidak ditemukan"
      fi

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

      echo "✅ Uninstall selesai untuk instance: $WP_NAME"
      ;;

    2)
      echo "🧱 Menghapus seluruh stack LEMP..."
      apt purge nginx mariadb-server php php-mysql php-fpm -y
      apt autoremove --purge -y
      rm -rf /var/lib/mysql
      rm -rf /etc/mysql
      rm -rf /var/log/mysql
      rm -rf /var/run/mysqld
      echo "✅ Semua paket LEMP telah dihapus"
      ;;

    0)
      echo "👋 Keluar."
      exit 0
      ;;

    *)
      echo "❌ Pilihan tidak valid."
      ;;
  esac

  echo ""
  read -rp "Tekan Enter untuk kembali ke menu..."
done
