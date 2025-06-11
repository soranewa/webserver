#!/bin/bash

echo "🧹 UNINSTALL WORDPRESS INSTANCE"

read -p "Masukkan nama folder instalasi WordPress yang ingin dihapus (contoh: "blog"): " WP_NAME
WP_DIR="/var/www/$WP_NAME"
NGINX_CONF="/etc/nginx/sites-available/$WP_NAME"
NGINX_LINK="/etc/nginx/sites-enabled/$WP_NAME"
WPCONFIG="$WP_DIR/wp-config.php"

# Konfirmasi
echo "Akan menghapus direktori: $WP_DIR"
echo "Akan menghapus konfigurasi nginx: $NGINX_CONF"
read -p "Yakin ingin melanjutkan? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "❌ Dibatalkan." && exit 0

# Coba ambil nama DB & user dari wp-config.php
if [ -f "$WPCONFIG" ]; then
    DB_NAME=$(grep DB_NAME "$WPCONFIG" | cut -d \' -f 4)
    DB_USER=$(grep DB_USER "$WPCONFIG" | cut -d \' -f 4)

    echo "🗃️ Database terdeteksi dari wp-config.php:"
    echo "   DB_NAME = $DB_NAME"
    echo "   DB_USER = $DB_USER"

    read -p "Ingin hapus database dan user MySQL ini? (y/n): " DELETE_DB
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

# Reload nginx
echo "🔄 Reload nginx..."
systemctl reload nginx

# Tanyakan apakah ingin uninstall seluruh stack LEMP
read -p "Apakah ingin menghapus semua paket LEMP dari sistem (nginx, mariadb, php)? (y/n): " FULL_REMOVE
if [[ "$FULL_REMOVE" == "y" ]]; then
    apt purge nginx mariadb-server php php-mysql php-fpm -y
    apt autoremove --purge -y
    echo "🧹 Semua paket LEMP telah dihapus"
fi

echo "✅ Uninstall selesai untuk instance: $WP_NAME"
