#!/bin/bash

WEB_ROOT="/var/www"

while true; do
echo "======================================"
echo "🧰 MANAGE WEB STATIC:"
echo "======================================"
echo "1. Buat Folder Website (+ Port Nginx)"
echo "2. Hapus Folder Website (+ Port)"
echo "3. Buat Database (Sesuai Prefix Folder)"
echo "4. Hapus Database"
echo "0. Keluar"
echo "======================================"
read -rp "Pilih opsi (0-4): " MENU

case $MENU in
1)
  echo ""
  echo "📂 List Website:"
  ls -1 "$WEB_ROOT"

  echo ""
  echo "🔌 Port Nginx in Use:"
  ls /etc/nginx/sites-available/web_* 2>/dev/null | cut -d'_' -f2

  read -rp "📁 Nama Folder Baru (misal: mysite): " FOLDER
  TARGET="$WEB_ROOT/$FOLDER"
  if [[ -d "$TARGET" ]]; then
    echo "❌ Folder sudah ada!"
    exit 1
  fi
  mkdir -p "$TARGET"
  chown -R www-data:www-data "$TARGET"

  read -rp "🔢 Masukkan port baru (1024-65535): " PORT
  PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
  cat > "/etc/nginx/sites-available/web_$PORT" <<EOF
server {
    listen $PORT;
    root $TARGET;
    index index.php index.html;
    server_name localhost;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  ln -sf "/etc/nginx/sites-available/web_$PORT" "/etc/nginx/sites-enabled/web_$PORT"
  nginx -t && systemctl reload nginx
  echo "✅ Website dibuat di $TARGET"
  echo "🌐 Dapat diakses di: http://$(hostname -I | awk '{print $1}'):$PORT"
  ;;

2)
  echo ""
  echo "📂 List Folder:"
  FOLDERS=$(ls -1 "$WEB_ROOT")
  PS3="Select Number: "
  select FOLDER in $FOLDERS; do
    [[ -n "$FOLDER" ]] && break
    echo "❌ Pilihan tidak valid."
  done

  TARGET="$WEB_ROOT/$FOLDER"
  if [[ ! -d "$TARGET" ]]; then
    echo "❌ Folder tidak ditemukan."
    exit 1
  fi

  rm -rf "$TARGET"
  echo "✅ Folder $FOLDER dihapus."

  for conf in /etc/nginx/sites-available/web_*; do
    ROOT=$(grep "root " "$conf" | awk '{print $2}' | sed 's/;//')
    if [[ "$ROOT" == "$TARGET" ]]; then
      PORT=$(basename "$conf" | cut -d'_' -f2)
      rm -f "$conf" "/etc/nginx/sites-enabled/web_$PORT"
      echo "✅ Konfigurasi Nginx di port $PORT dihapus."
    fi
  done
  systemctl reload nginx
  ;;

3)
  echo ""
  echo "📂 List Folder:"
  FOLDERS=$(ls -1 "$WEB_ROOT")
  PS3="Select Number: "
  select FOLDER in $FOLDERS; do
    [[ -n "$FOLDER" ]] && break
    echo "❌ Pilihan tidak valid."
  done

  DB_NAME="db_${FOLDER}_$(date +%s | tail -c 5)"
  DB_USER="user_${FOLDER}_$RANDOM"
  DB_PASS=$(openssl rand -base64 10)

  mysql -uroot -e "
CREATE DATABASE \`${DB_NAME}\`;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
"
  echo "✅ Database dan user dibuat:"
  echo "🗃️ DB_NAME: $DB_NAME"
  echo "👤 DB_USER: $DB_USER"
  echo "🔑 DB_PASS: $DB_PASS"
  ;;

4)
  echo ""
  echo "🗃️ List Database:"
  DBS=$(mysql -uroot -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
  PS3="Select Number: "
  select DB_NAME in $DBS; do
    [[ -n "$DB_NAME" ]] && break
    echo "❌ Pilihan tidak valid."
  done

  echo ""
  echo "👤 List User:"
  USERS=$(mysql -uroot -e "SELECT User FROM mysql.user;" 2>/dev/null | tail -n +2)
  echo "$USERS"

  read -rp "Masukkan nama user yang ingin dihapus (bisa copy dari atas): " DB_USER
  echo "⚠️ Akan menghapus database '$DB_NAME' dan user '$DB_USER'"
  read -rp "Lanjutkan? (y/n): " CONFIRM

  if [[ "$CONFIRM" == "y" ]]; then
    mysql -uroot -e "
      DROP DATABASE IF EXISTS \`${DB_NAME}\`;
      DROP USER IF EXISTS '${DB_USER}'@'localhost';
      FLUSH PRIVILEGES;
    "
    echo "✅ Database dan user berhasil dihapus."
  else
    echo "❌ Dibatalkan."
  fi
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
