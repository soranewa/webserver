#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

WEB_ROOT="/var/www"

while true; do
clear
echo "======================================"
echo "🧰 MENU:"
echo "======================================"
echo "1. Buat Folder Website (+ Port Nginx)"
echo "2. Hapus Folder Website (+ Port)"
echo "3. Buat Database (Sesuai Prefix Folder)"
echo "4. Hapus Database"
# echo "5. Install TinyFileManager (Root Server)"
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
  ls /etc/nginx/sites-available/web_* /etc/nginx/sites-available/wp_* 2>/dev/null \
    | grep -E '/(web|wp)_[0-9]+' \
    | cut -d'_' -f2

  read -rp "📁 Nama Folder Baru (misal: mysite): " FOLDER
  TARGET="$WEB_ROOT/$FOLDER"
  if [[ -d "$TARGET" ]]; then
    echo "❌ Folder sudah ada!"
    sleep 1
    continue
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
    sleep 1
    continue
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
  echo "🗃️ List Database yang sudah ada:"
  mysql -uroot -e "SHOW DATABASES;" 2>/dev/null | tail -n +2

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

# 5)
#   clear
#   echo ""
#   echo "📂 Daftar Folder Web di /var/www:"
#   FOLDERS=( $(ls -1 "$WEB_ROOT") )
#   for i in "${!FOLDERS[@]}"; do
#     printf "%2d) %s\n" $((i+1)) "${FOLDERS[$i]}"
#   done

#   while true; do
#     read -rp "Pilih nomor folder target: " F_IDX
#     [[ "$F_IDX" =~ ^[0-9]+$ ]] && (( F_IDX >= 1 )) && (( F_IDX <= ${#FOLDERS[@]} )) && break
#     echo "❌ Nomor tidak valid!"
#   done

#   FOLDER="${FOLDERS[$((F_IDX-1))]}"
#   TARGET="$WEB_ROOT/$FOLDER"

#   if [[ ! -d "$TARGET" ]]; then
#     echo "❌ Folder tidak ditemukan!"
#     sleep 2
#     continue
#   fi

#   echo ""
#   echo "🔌 Mendeteksi konfigurasi Nginx yang cocok..."
#   PORTS=()
#   mapfile -t PORT_CONF < <(grep -l "root $TARGET;" /etc/nginx/sites-available/web_* 2>/dev/null)
  
#   if [[ ${#PORT_CONF[@]} -eq 0 ]]; then
#     echo "❌ Tidak ada konfigurasi Nginx untuk folder ini!"
#     sleep 2
#     continue
#   fi

#   for conf in "${PORT_CONF[@]}"; do
#     PORT_NUM=$(basename "$conf" | cut -d'_' -f2)
#     PORTS+=("$PORT_NUM")
#     echo "✔ Port ditemukan: $PORT_NUM"
#   done

#   PORT_FOUND="${PORTS[0]}"
#   if [[ ${#PORTS[@]} -gt 1 ]]; then
#     echo ""
#     echo "🔢 Ditemukan beberapa port:"
#     for i in "${!PORTS[@]}"; do
#       printf "%2d) %s\n" $((i+1)) "${PORTS[$i]}"
#     done
#     while true; do
#       read -rp "Pilih nomor port: " P_IDX
#       [[ "$P_IDX" =~ ^[0-9]+$ ]] && (( P_IDX >= 1 )) && (( P_IDX <= ${#PORTS[@]} )) && break
#       echo "❌ Nomor tidak valid!"
#     done
#     PORT_FOUND="${PORTS[$((P_IDX-1))]}"
#   fi

#   echo ""
#   read -rp "👤 Masukkan username login: " TINYUSER
#   while true; do
#     read -rp "🔑 Masukkan password (min 8 karakter): " TINYPASS
#     echo
#     [[ ${#TINYPASS} -ge 8 ]] && break
#     echo "❌ Password terlalu pendek!"
#   done

#   echo ""
#   echo "⬇️ Mengunduh TinyFileManager..."
#   FILE="$TARGET/tinyfilemanager.php"
#   wget -qO "$FILE" https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php || {
#     echo "❌ Gagal mengunduh TinyFileManager!"
#     sleep 2
#     continue
#   }

#   echo "🛠️ Konfigurasi TinyFileManager..."
#   sed -i "s|\$root_path = .*|\$root_path = '/';|" "$FILE"
#   sed -i '/auth_users/d' "$FILE"
#   sed -i '/use_login/d' "$FILE"
#   sed -i '/default_timezone/d' "$FILE"
#   sed -i '/theme/d' "$FILE"

#   echo "🔐 Membuat config.php..."
#   HASHED_PASS=$(php -r "echo password_hash('$TINYPASS', PASSWORD_DEFAULT);")
#   cat > "$TARGET/config.php" <<EOF
# <?php
# \$auth_users = array(
#   '$TINYUSER' => '$HASHED_PASS'
# );
# \$use_login = true;
# \$theme = "light";
# \$default_timezone = "Asia/Jakarta";
# EOF

#   chown www-data:www-data "$TARGET/config.php"
#   chmod 666 "$TARGET/config.php"
#   chmod o+rx /home 2>/dev/null || true

#   echo "📐 Konfigurasi upload PHP..."
#   PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
#   PHP_INI="/etc/php/$PHP_VER/fpm/php.ini"
#   sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 2048M/' "$PHP_INI"
#   sed -i 's/^post_max_size\s*=.*/post_max_size = 2048M/' "$PHP_INI"
#   systemctl restart php$PHP_VER-fpm >/dev/null 2>&1

#   IP=$(hostname -I | awk '{print $1}')
#   echo ""
#   echo "✅ TinyFileManager berhasil diinstal!"
#   echo "===================================="
#   echo "🌐 URL: http://$IP:$PORT_FOUND/tinyfilemanager.php"
#   echo "👤 Username: $TINYUSER"
#   echo "🔑 Password: $TINYPASS"
#   echo "📌 Root Path: / (akses penuh)"
#   echo "===================================="
#   ;;

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
clear
continue
done
