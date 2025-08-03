#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

WEB_ROOT="/var/www"

# === Fungsi Validasi Port ===
valid_port() {
  [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -ge 1024 ] && [ "$1" -le 65535 ]
}

# === Cek Root ===
if [[ $EUID -ne 0 ]]; then
  echo "Script harus dijalankan sebagai root!"
  exit 1
fi

while true; do
  clear
  echo "======================================="
  echo "🧱 INSTALLER PANEL"
  echo "======================================="
  echo "1. Install WordPress Instance"
  echo "2. Install LEMP Stack (Nginx, PHP, MariaDB)"
  echo "0. Keluar"
  echo "======================================="
  read -rp "Pilih opsi (0-2): " MENU

  case $MENU in
  1)
    echo ""
    echo "📂 List Folder WordPress yang sudah ada:"
    ls -1 "$WEB_ROOT"
  
    echo ""
    echo "🔌 Port Nginx in Use:"
    ls /etc/nginx/sites-available/web_* /etc/nginx/sites-available/wp_* 2>/dev/null \
    | grep -E '/(web|wp)_[0-9]+' \
    | cut -d'_' -f2
    # echo ""
    # echo "🔢 Port Nginx yang sudah digunakan:"
    # ls /etc/nginx/sites-available/wp_* 2>/dev/null | cut -d'_' -f2

    echo ""
    read -rp "📁 Nama folder instalasi WordPress (contoh: wp_blog1): " WP_FOLDER
    WP_DIR="$WEB_ROOT/$WP_FOLDER"

    while [[ -z "$WP_FOLDER" || -d "$WP_DIR" ]]; do
      if [[ -d "$WP_DIR" ]]; then
        echo "❌ Direktori $WP_DIR sudah ada. Masukkan nama lain!"
      fi
      read -rp "Nama folder baru: " WP_FOLDER
      WP_DIR="$WEB_ROOT/$WP_FOLDER"
    done

    read -rp "🔢 Masukkan PORT untuk WordPress (1024-65535): " WP_PORT
    until valid_port "$WP_PORT"; do
      echo "❌ Port tidak valid!"
      read -rp "Port (1024-65535): " WP_PORT
    done

    DB_NAME="wp$(date +%s)"
    DB_USER="user_${RANDOM}"
    DB_PASS=$(openssl rand -base64 12)

    mkdir -p "$WP_DIR"
    chown -R www-data:www-data "$WP_DIR"

    echo "⬇️ Mengunduh WordPress..."
    wget -q https://wordpress.org/latest.zip -O /tmp/latest.zip
    unzip -q /tmp/latest.zip -d /tmp/
    mv /tmp/wordpress/* "$WP_DIR"
    rm -rf /tmp/latest.zip /tmp/wordpress

    echo "🛠️ Mengatur database..."
    mysql -e "CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"
    safe_db_name=$(printf '%s' "$DB_NAME" | sed -e 's/[\/&\\]/\\&/g')
    safe_db_user=$(printf '%s' "$DB_USER" | sed -e 's/[\/&\\]/\\&/g')
    safe_db_pass=$(printf '%s' "$DB_PASS" | sed -e 's/[\/&\\]/\\&/g')
    
    sed -i "s/database_name_here/$safe_db_name/" "$WP_DIR/wp-config.php"
    sed -i "s/username_here/$safe_db_user/" "$WP_DIR/wp-config.php"
    sed -i "s/password_here/$safe_db_pass/" "$WP_DIR/wp-config.php"

    chown -R www-data:www-data "$WP_DIR"
    find "$WP_DIR" -type d -exec chmod 755 {} \;
    find "$WP_DIR" -type f -exec chmod 644 {} \;

    SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" "$WP_DIR/wp-config.php"
    awk -v salt="$SALT" '/^\/\* That/{print salt}1' "$WP_DIR/wp-config.php" > "$WP_DIR/wp-config.temp.php"
    mv "$WP_DIR/wp-config.temp.php" "$WP_DIR/wp-config.php"

    NGINX_CONF="/etc/nginx/sites-available/wp_$WP_PORT"
    PHP_FPM_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_SOCK="/run/php/php${PHP_FPM_VERSION}-fpm.sock"

    cat > "$NGINX_CONF" <<EOF
    server {
        listen $WP_PORT;
        root $WP_DIR;
        index index.php index.html;
        server_name localhost;
        client_max_body_size 64M;
    
        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }
    
        location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:$PHP_SOCK;
        }
    
        location ~ /\.ht {
            deny all;
        }
    }
    EOF
    ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx

    IP_LOCAL=$(hostname -I | awk '{print $1}')
    echo -e "\n✅ WordPress berhasil diinstal!"
    echo "🌐 Akses: http://${IP_LOCAL}:$WP_PORT"
    echo "📁 Direktori: $WP_DIR"
    echo "🗃️ DB: $DB_NAME, User: $DB_USER, Pass: $DB_PASS"
    ;;

  2)
    echo "🧱 Menginstal LEMP Stack..."
    apt update -y
    apt install -y nginx mariadb-server php php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip unzip curl

    PHP_FPM_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_FPM_SERVICE="php${PHP_FPM_VERSION}-fpm"

    systemctl enable nginx mariadb "$PHP_FPM_SERVICE"
    systemctl start nginx mariadb "$PHP_FPM_SERVICE"

    echo "✅ LEMP Stack aktif."
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
